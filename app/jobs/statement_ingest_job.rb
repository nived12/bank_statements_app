class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    temp_file = Tempfile.new([ "statement", ".pdf" ], binmode: true)
    temp_file.write(statement.file.download)
    temp_file.rewind

    # 1) Get text: try text layer; if invalid/empty, try OCR (if enabled)
    text_layer = TextExtractor.extract_text_layer(temp_file.path)
    source = "text"
    text =
      if TextExtractor.valid_text?(text_layer)
        text_layer
      else
        Rails.logger.info("TextExtractor: invalid/empty text layer; trying OCR…")
        ocr_text = Ocr::Service.extract_text(temp_file.path)
        if TextExtractor.valid_text?(ocr_text)
          source = "ocr"
          ocr_text
        else
          statement.update(
            status: "error",
            processed_at: Time.current,
            error_message: "No extractable text found after text layer + OCR. Try higher DPI (OCR_DPI), enable OCR_DEBUG=1, or ensure the PDF isn’t password-protected."
          )
          return
        end
      end

    # 2) Parse: AI first (if enabled), else deterministic Generic
    parsed = nil
    if ai_enabled?
      begin
        parsed = Ai::PostProcessor.new.call(
          raw_text: text,
          bank_name: statement.bank_account.bank_name,
          account_number: statement.bank_account.account_number
        )
      rescue => e
        Rails.logger.warn("AI parse failed: #{e.message}; falling back to deterministic parser")
        parsed = nil
      end
    end

    parsed ||= PdfParser::Generic.new.parse(
      text,
      context: {
        bank_name: statement.bank_account.bank_name,
        account_number: statement.bank_account.account_number
      }
    )

    # 3) Normalize + annotate
    normalize_parsed!(parsed)
    parsed["extraction_source"] = source if parsed.is_a?(Hash)

    # 4) Persist
    statement.update(
      parsed_json: parsed,
      status: "parsed",
      processed_at: Time.current
    )

  rescue => e
    statement.update(
      status: "error",
      processed_at: Time.current,
      error_message: e.message.to_s[0, 1000]
    )
    Rails.logger.error("StatementIngestJob failed for #{statement&.id}: #{e.message}\n#{e.backtrace.join("\n")}")
  ensure
    temp_file.close! if temp_file
  end

  private

  def ai_enabled?
    ENV.fetch("AI_API_KEY", "").strip != ""
  end

  # Ensure canonical budgeting type + optional bank_entry_type
  def normalize_parsed!(hash)
    return unless hash.is_a?(Hash) && hash["transactions"].is_a?(Array)

    hash["transactions"].each do |t|
      amt =
        case t["amount"]
        when String then t["amount"].to_s.tr(",", "").to_f
        else t["amount"].to_f
        end

      # If AI stuck credit/debit in "type", move it
      raw_type = t["type"].to_s.downcase.strip
      t["bank_entry_type"] = raw_type if %w[credit debit].include?(raw_type)

      # Canonical: income/expense by sign
      t["type"] = amt < 0 ? "expense" : "income"

      # Clean bank_entry_type
      t["bank_entry_type"] =
        case t["bank_entry_type"].to_s.downcase.strip
        when "credit", "cr" then "credit"
        when "debit", "dr"  then "debit"
        else nil
        end

      # Defaults
      t["fixed_or_variable"] = %w[fijo variable].include?(t["fixed_or_variable"]) ? t["fixed_or_variable"] : "variable"
      t["category"] ||= "Uncategorized"
      t["confidence"] = t["confidence"].to_f if t["confidence"]
    end
  end
end
