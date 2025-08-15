# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    temp_file = create_temp_file(statement)
    text = extract_text(temp_file.path, statement)
    return unless text

    # Extract financial data and process text
    financial_data = extract_financial_data(text, statement)
    masked_text = apply_pii_redaction(text, statement)
    filtered_text = filter_text(masked_text, statement)
    text_chunks = prepare_text_chunks(filtered_text)

    # Parse with AI or fallback
    ai_result = parse_with_ai(text_chunks, masked_text, statement)

    if ai_result.nil?
      Rails.logger.info("AI parse returned nil, using fallback parser")
      fallback_result = PdfParser::Generic.new.parse(text, context: {})
      parsed = fallback_result
    else
      parsed = ai_result
    end

    # Restore PII and finalize
    if pii_redaction_enabled?
      parsed = restore_pii_tokens(parsed, statement)
    end
    annotate_parsed_data(parsed, text_chunks)
    import_transactions(statement, parsed)
    create_financial_summary(statement, financial_data) if financial_data.present?

    statement.update(
      parsed_json: parsed,
      status: "parsed",
      processed_at: Time.current
    )

  rescue => e
    handle_error(statement, e)
  ensure
    temp_file&.close!
  end

  private

  def create_temp_file(statement)
    temp_file = Tempfile.new([ "statement", ".pdf" ], binmode: true)
    temp_file.write(statement.file.download)
    temp_file.rewind
    temp_file
  end

  def extract_text(file_path, statement)
    text_layer = TextExtractor.extract_text_layer(file_path)

    if TextExtractor.valid_text?(text_layer)
      @source = "text"
      text_layer
    else
      Rails.logger.info("TextExtractor: trying OCR...")
      ocr_text = Ocr::Service.extract_text(file_path)

      if TextExtractor.valid_text?(ocr_text)
        @source = "ocr"
        ocr_text
      else
        statement.update(
          status: "error",
          processed_at: Time.current,
          error_message: "No extractable text found after text layer + OCR."
        )
        nil
      end
    end
  end

  def extract_financial_data(text, statement)
    TransactionTextFilter.extract_financial_data(text, bank_name: statement.bank_account.bank_name)
  end

  def apply_pii_redaction(text, statement)
    return text unless pii_redaction_enabled?

    redacted, map, hmac = PiiRedactor.new.redact_preserving_transactions(text)
    statement.update!(redaction_map: map, redaction_hmac: hmac)
    redacted
  rescue => e
    Rails.logger.error("[PII] Redaction failed: #{e.message}")
    statement.update(
      status: "error",
      processed_at: Time.current,
      error_message: "PII redaction failed: #{e.message}"
    )
    raise
  end

  def filter_text(text, statement)
    filtered = TransactionTextFilter.filter_for_transactions(text, bank_name: statement.bank_account.bank_name)
    Rails.logger.info("Text filtering: #{text.length} → #{filtered.length} chars")
    filtered
  end

  def prepare_text_chunks(text)
    if text.length > 8000
      chunk_text_for_ai(text)
    else
      [ text ]
    end
  end

  def parse_with_ai(text_chunks, masked_text, statement)
    return nil unless ai_api_available?

    user_categories = statement.bank_account.user.categories

    if text_chunks.length > 1
      process_multiple_chunks(text_chunks, user_categories, statement)
    else
      Ai::PostProcessor.new.call(
        raw_text: masked_text,
        bank_name: statement.bank_account.bank_name,
        account_number: statement.bank_account.account_number,
        categories: user_categories
      )
    end
  rescue => e
    Rails.logger.warn("AI parse failed: #{e.message}; falling back to deterministic parser")
    nil
  end

  def restore_pii_tokens(parsed, statement)
    return parsed unless statement.redaction_hmac.present? && statement.redaction_map.present?

    Rails.logger.info("[PII] Restoring tokens from map: #{statement.redaction_map.inspect}")
    restored = restore_tokens_deep(parsed, statement.redaction_map)
    Rails.logger.info("[PII] Token restoration completed")
    restored
  rescue => e
    Rails.logger.error("[PII] Token restoration error: #{e.message}")
    raise RuntimeError, "PII token restoration failed: #{e.message}"
  end

  def annotate_parsed_data(parsed, text_chunks)
    return unless parsed.is_a?(Hash)

    parsed["extraction_source"] = @source
  end

  def import_transactions(statement, parsed)
    count = Transactions::Importer.call(statement, json: parsed)
  end

  def create_financial_summary(statement, financial_data)
    period_duration = calculate_period_duration(financial_data[:period_dates])

    StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: financial_data[:statement_type],
      initial_balance: financial_data[:initial_balance],
      final_balance: financial_data[:final_balance],
      statement_period_start: financial_data[:period_dates]&.values&.first,
      statement_period_end: financial_data[:period_dates]&.values&.last,
      days_in_period: period_duration,
      total_commissions: financial_data[:commission_info]&.values&.first,
      total_fees: financial_data[:commission_info]&.values&.last,
      statement_type_data: financial_data[:statement_type_data] || {}
    )
  rescue => e
    Rails.logger.error("Failed to create financial summary: #{e.message}")
    # Don't fail the entire job if financial summary creation fails
  end

  def calculate_period_duration(period_dates)
    return nil unless period_dates&.any?

    start_date = period_dates.values.first
    end_date = period_dates.values.last
    return nil unless start_date && end_date

    (end_date - start_date).to_i + 1
  end

  def handle_error(statement, error)
    statement.update(
      status: "error",
      processed_at: Time.current,
      error_message: error.message.to_s[0, 1000]
    )
    Rails.logger.error("StatementIngestJob failed: #{error.message}")
  end

  def pii_redaction_enabled?
    ENV["PII_REDACTION_ENABLED"] == "1"
  end

  def ai_api_available?
    ENV.fetch("AI_API_KEY", "").strip.present?
  end

  def restore_tokens_deep(obj, map)
    case obj
    when String
      map.reduce(obj.dup) { |s, (token, orig)| s.gsub(token, orig.to_s) }
    when Array
      obj.map { |v| restore_tokens_deep(v, map) }
    when Hash
      obj.transform_values { |v| restore_tokens_deep(v, map) }
    else
      obj
    end
  end

  def chunk_text_for_ai(text, max_length: 8000)
    chunks = []
    current_chunk = ""

    text.split("\n").each do |line|
      if (current_chunk + line).length > max_length && current_chunk.present?
        chunks << current_chunk.strip
        current_chunk = line
      else
        current_chunk += line + "\n"
      end
    end

    chunks << current_chunk.strip if current_chunk.present?
    chunks
  end

  def process_multiple_chunks(text_chunks, user_categories, bank_account)
    all_transactions = []
    opening_balance = nil
    closing_balance = nil

    text_chunks.each_with_index do |chunk, index|
      # Apply PII redaction if enabled
      if pii_redaction_enabled?
        redacted, _map, _hmac = PiiRedactor.new.redact_preserving_transactions(chunk)
        chunk = redacted
      end

      chunk_parsed = Ai::PostProcessor.new.call(
        raw_text: chunk,
        bank_name: bank_account.bank_name,
        account_number: bank_account.account_number,
        categories: user_categories
      )

      next unless chunk_parsed.is_a?(Hash) && chunk_parsed["transactions"].is_a?(Array)

      all_transactions.concat(chunk_parsed["transactions"])
      opening_balance = chunk_parsed["opening_balance"] if index == 0
      closing_balance = chunk_parsed["closing_balance"] if index == text_chunks.length - 1
    end

    {
      "opening_balance" => opening_balance,
      "closing_balance" => closing_balance,
      "transactions" => all_transactions,
      "extraction_source" => "text_chunked"
    }
  end
end
