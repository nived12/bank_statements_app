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

    # 2) Mask PII
    masked_text =
      if ENV["PII_REDACTION_ENABLED"] == "1"
        redacted, map, hmac = PiiRedactor.new.redact(text)
        statement.update!(
          redaction_map: map,
          redaction_hmac: hmac
        )
        redacted
      else
        text
      end

    # 3) Parse (AI first if enabled; fallback to deterministic)
    parsed = nil
    if ENV.fetch("AI_API_KEY", "").strip != ""
      begin
        user_categories = statement.bank_account.user.categories
        parsed = Ai::PostProcessor.new.call(
          raw_text: masked_text,
          bank_name: statement.bank_account.bank_name,
          account_number: statement.bank_account.account_number,
          categories: user_categories
        )
      rescue => e
        Rails.logger.warn("AI parse failed: #{e.message}; falling back to deterministic parser")
        parsed = nil
      end
    end

    # 4) Integrity check: Verify HMAC
    if ENV["PII_REDACTION_ENABLED"] == "1" && statement.redaction_hmac.present?
      begin
        _redacted_again, _map2, hmac_again = PiiRedactor.new.redact(text)
        unless ActiveSupport::SecurityUtils.secure_compare(hmac_again, statement.redaction_hmac)
          Rails.logger.warn("[PII] HMAC mismatch for StatementFile##{statement.id}")
        end
      rescue => e
        Rails.logger.warn("[PII] HMAC verification error for StatementFile##{statement.id}: #{e.message}")
      end
    end

    # 5) Restore tokens back to originals if redaction was enabled
    if ENV["PII_REDACTION_ENABLED"] == "1" && statement.redaction_hmac.present?
      begin
        _redacted_again, _map2, hmac_again = PiiRedactor.new.redact(text)
        unless ActiveSupport::SecurityUtils.secure_compare(hmac_again, statement.redaction_hmac)
          Rails.logger.warn("[PII] HMAC mismatch for StatementFile##{statement.id}")
        end
      rescue => e
        Rails.logger.warn("[PII] HMAC verification error for StatementFile##{statement.id}: #{e.message}")
      end

      parsed = restore_tokens_deep(parsed, map) if map.is_a?(Hash)
    end

    parsed ||= PdfParser::Generic.new.parse(text, context: {})

    # 6) Annotate
    parsed["extraction_source"] = source if parsed.is_a?(Hash)

    # 7) Import using the in-memory parsed hash (not yet saved)
    count = Transactions::Importer.call(statement, json: parsed)
    parsed["imported_count"] = count if parsed.is_a?(Hash)

    # 7) Persist once
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

  private

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
end
