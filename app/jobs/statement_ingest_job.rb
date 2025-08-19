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
      fallback_result = parse_with_fallback_parser(text, statement)
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

      TextExtractor.debug_extraction(file_path)

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
    financial_data = TransactionTextFilter.extract_financial_data(text, bank_name: statement.bank_account.bank_name)
    financial_data
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

  def parse_with_fallback_parser(text, statement)
    # Use the bank's parser_type to determine which parser to use
    parser_type = statement.bank_account.parser_type

    Rails.logger.info("Using fallback parser: #{parser_type}")

    case parser_type
    when "bbva"
      # BBVA parser will auto-detect credit card vs savings
      PdfParser::BbvaCreditCard.new.parse(text, context: {})
    when "santander"
      # Use Santander parser when available
      PdfParser::Generic.new.parse(text, context: {})
    when "banorte"
      # Use Banorte parser when available
      PdfParser::Generic.new.parse(text, context: {})
    when "banamex"
      # Use Banamex parser when available
      PdfParser::Generic.new.parse(text, context: {})
    else
      # Generic parser for unsupported banks
      PdfParser::Generic.new.parse(text, context: {})
    end
  rescue => e
    Rails.logger.error("Fallback parser failed: #{e.message}, using generic parser")
    PdfParser::Generic.new.parse(text, context: {})
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
    return unless parsed["transactions"]

    # Get user's categories for lookup
    user_categories = statement.user.categories

    # Clear existing transactions for this statement to avoid duplicates
    existing_count = statement.transactions.count
    if existing_count > 0
      Rails.logger.info("Clearing #{existing_count} existing transactions for statement #{statement.id}")
      statement.transactions.destroy_all
    end

    # Import transactions
    parsed["transactions"].each do |transaction_data|
      # Find the category by name
      category = find_category_by_name(user_categories, transaction_data["category"])
      sub_category = find_category_by_name(user_categories, transaction_data["sub_category"]) if transaction_data["sub_category"].present?

      # Use subcategory if available, otherwise use main category
      # This ensures we get the most specific categorization
      final_category = sub_category || category

      transaction = Transaction.create!(
        statement_file: statement,
        bank_account: statement.bank_account,
        user: statement.user,
        date: Date.parse(transaction_data["date"]),
        description: transaction_data["description"],
        amount: transaction_data["amount"],
        transaction_type: transaction_data["transaction_type"],
        bank_entry_type: transaction_data["bank_entry_type"],
        merchant: transaction_data["merchant"],
        reference: transaction_data["reference"],
        category: final_category
      )
    end

    # Import financial summaries from AI parsing if available
    if parsed["financial_summaries"]&.any?
      parsed["financial_summaries"].each do |summary_data|
        # Create StatementFinancialSummary records based on the type
        case summary_data["type"]
        when "balance"
          # Create financial summary for balance information
          if summary_data["description"]&.downcase&.include?("opening") || summary_data["description"]&.downcase&.include?("inicial")
            # This is an opening balance
            create_ai_financial_summary(statement, summary_data, "opening_balance")
          elsif summary_data["description"]&.downcase&.include?("closing") || summary_data["description"]&.downcase&.include?("final")
            # This is a closing balance
            create_ai_financial_summary(statement, summary_data, "closing_balance")
          else
            # Generic balance entry
            create_ai_financial_summary(statement, summary_data, "balance")
          end
        when "fee", "commission"
          # Create financial summary for fees/commissions
          create_ai_financial_summary(statement, summary_data, "fee")
        when "installment"
          # Create financial summary for installment information
          create_ai_financial_summary(statement, summary_data, "installment")
        else
          # Handle any other types
          create_ai_financial_summary(statement, summary_data, "other")
        end
      end
    end

    Rails.logger.info("Imported #{parsed['transactions'].count} transactions and #{parsed['financial_summaries']&.count || 0} financial summaries")
  end

  def create_financial_summary(statement, financial_data)
    # Provide defaults for missing required fields
    statement_type = financial_data[:statement_type] || "savings"
    initial_balance = financial_data[:initial_balance] || 0.0
    final_balance = financial_data[:final_balance] || 0.0
    period_dates = financial_data[:period_dates] || {}

    # Calculate period duration with fallback
    period_duration = calculate_period_duration(period_dates)
    if period_duration.nil?
      # Fallback: use statement creation date as period
      period_duration = 30 # Default to 30 days
    end

    # Ensure we have at least some period dates
    if period_dates.empty?
      period_dates = {
        "start" => statement.created_at.to_date - 30.days,
        "end" => statement.created_at.to_date
      }
    end

    # Create the financial summary with defaults
    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: statement_type,
      initial_balance: initial_balance,
      final_balance: final_balance,
      statement_period_start: period_dates["start"] || period_dates.values.first,
      statement_period_end: period_dates["end"] || period_dates.values.last,
      days_in_period: period_duration,
      total_commissions: financial_data[:commission_info]&.values&.first || 0.0,
      total_fees: financial_data[:commission_info]&.values&.last || 0.0,
      statement_type_data: financial_data[:statement_type_data] || {}
    )

    summary
  rescue => e
    Rails.logger.error("Failed to create financial summary: #{e.message}")
    # Don't fail the entire job if financial summary creation fails
    nil
  end

  def create_ai_financial_summary(statement, summary_data, summary_type)
    # Extract data from AI summary
    amount = summary_data["amount"] || 0.0
    description = summary_data["description"] || ""
    date = summary_data["date"] || statement.created_at.to_date
    details = summary_data["details"] || {}
    raw_text = summary_data["raw_text"] || ""

    # Determine statement type based on bank account
    statement_type = statement.bank_account.bank.code.downcase == "bbva" ? "credit" : "savings"

    # Create the financial summary
    # For single-date entries, use a 1-day period
    period_start = date
    period_end = date + 1.day

    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: statement_type,
      initial_balance: summary_type == "opening_balance" ? amount : 0.0,
      final_balance: summary_type == "closing_balance" ? amount : 0.0,
      statement_period_start: period_start,
      statement_period_end: period_end,
      days_in_period: 2,
      total_commissions: summary_type == "fee" ? amount : 0.0,
      total_fees: summary_type == "commission" ? amount : 0.0,
      statement_type_data: {
        "ai_extracted_type" => summary_type,
        "ai_description" => description,
        "ai_details" => details,
        "ai_raw_text" => raw_text,
        "ai_amount" => amount
      }
    )

    Rails.logger.info("Created AI financial summary: #{summary_type} - #{description} - #{amount}")
    summary
  rescue => e
    Rails.logger.error("Failed to create AI financial summary: #{e.message}")
    # Don't fail the entire job if financial summary creation fails
    nil
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
      error_message: "Statement processing failed: #{error.message}"
    )
    Rails.logger.error("StatementIngestJob failed for statement #{statement.id}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
  end

  def ai_api_available?
    ENV["AI_PROVIDER"].present? && ENV["AI_API_KEY"].present?
  end

  def pii_redaction_enabled?
    ENV["PII_REDACTION_ENABLED"] == "true"
  end

  def process_multiple_chunks(text_chunks, user_categories, statement)
    # Process multiple chunks and merge results
    results = []

    text_chunks.each_with_index do |chunk, index|
      Rails.logger.info("Processing chunk #{index + 1}/#{text_chunks.length}")

      chunk_result = Ai::PostProcessor.new.call(
        raw_text: chunk,
        bank_name: statement.bank_account.bank_name,
        account_number: statement.bank_account.account_number,
        categories: user_categories
      )

      if chunk_result && chunk_result["transactions"]
        results << chunk_result
      end
    end

    # Merge all results
    merged = {
      "opening_balance" => results.first&.dig("opening_balance"),
      "closing_balance" => results.last&.dig("closing_balance"),
      "transactions" => results.flat_map { |r| r["transactions"] || [] }
    }

    merged
  end

  def chunk_text_for_ai(text)
    # Simple chunking by character count
    chunk_size = 8000
    chunks = []

    text.scan(/.{1,#{chunk_size}}/m) do |chunk|
      chunks << chunk
    end

    chunks
  end

  def restore_tokens_deep(obj, map)
    case obj
    when Hash
      obj.transform_values { |v| restore_tokens_deep(v, map) }
    when Array
      obj.map { |v| restore_tokens_deep(v, map) }
    when String
      map[obj] || obj
    else
      obj
    end
  end

  def find_category_by_name(categories, category_name)
    return nil unless category_name.present?

    # Try to find by exact name match first (case-insensitive)
    category = categories.find { |c| c.name.downcase == category_name.downcase }
    return category if category

    # Try to find by partial match
    category = categories.find { |c| c.name.downcase.include?(category_name.downcase) || category_name.downcase.include?(c.name.downcase) }
    return category if category

    # Try common variations and mappings
    category_mappings = {
      "ingresos" => [ "income", "salary", "wages", "earnings" ],
      "comida" => [ "food", "restaurant", "dining", "groceries" ],
      "transporte" => [ "transport", "gas", "uber", "lyft", "taxi" ],
      "entretenimiento" => [ "entertainment", "movies", "games", "sports" ],
      "compras" => [ "shopping", "clothes", "electronics", "retail" ],
      "salud" => [ "health", "medical", "pharmacy", "doctor" ],
      "educación" => [ "education", "courses", "books", "training" ],
      "servicios" => [ "services", "utilities", "internet", "phone" ],
      "sin categorizar" => [ "uncategorized", "other", "miscellaneous" ],
      # New mappings for AI-returned categories
      "bancarios" => [ "servicios", "otros ingresos" ],
      "electrónicos" => [ "tecnología" ],
      "streaming" => [ "entretenimiento" ],
      "gaming" => [ "entretenimiento" ],
      "online" => [ "compras", "otros ingresos" ],
      "suscripciones" => [ "servicios" ],
      "aéreo" => [ "viajes" ],
      "pago" => [ "ingresos", "otros ingresos" ]
    }

    # Check if the category name matches any of the mapped variations
    category_mappings.each do |spanish_name, english_variations|
      if spanish_name.downcase == category_name.downcase
        # Find the first available category from the variations
        english_variations.each do |variation|
          category = categories.find { |c| c.name.downcase == variation.downcase }
          return category if category
        end
      end
    end

    # If no match found, log a warning and return nil
    Rails.logger.warn("Category not found: '#{category_name}'. Available categories: #{categories.map(&:name).join(', ')}")
    nil
  end
end
