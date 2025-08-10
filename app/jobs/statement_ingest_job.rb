# app/jobs/statement_ingest_job.rb
class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    temp_file = Tempfile.new([ "statement", ".pdf" ], binmode: true)
    temp_file.write(statement.file.download)
    temp_file.rewind

    # 1) Extract text (text layer → OCR if needed)
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
            error_message: "No extractable text found after text layer + OCR."
          )
          return
        end
      end

    # 2) Parse (AI first if enabled; fallback to deterministic)
    parsed = nil
    if ENV.fetch("AI_API_KEY", "").strip != ""
      begin
        user_categories = statement.bank_account.user.categories
        parsed = Ai::PostProcessor.new.call(
          raw_text: text,
          bank_name: statement.bank_account.bank_name,
          account_number: statement.bank_account.account_number,
          categories: user_categories
        )
      rescue => e
        Rails.logger.warn("AI parse failed: #{e.message}; falling back to deterministic parser")
        parsed = nil
      end
    end

    parsed ||= PdfParser::Generic.new.parse(text, context: {})

    # 3) Annotate
    parsed["extraction_source"] = source if parsed.is_a?(Hash)

    # 4) Import using the in-memory parsed hash (not yet saved)
    count = Transactions::Importer.call(statement, json: parsed)
    parsed["imported_count"] = count if parsed.is_a?(Hash)

    # 5) Persist once
    statement.update(
      parsed_json: parsed,
      status: "parsed",
      processed_at: Time.current
    )

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
end
