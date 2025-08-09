class StatementIngestJob < ApplicationJob
  queue_as :default

  def perform(statement_file_id)
    statement = StatementFile.find_by(id: statement_file_id)
    return unless statement

    statement.update(status: "processing")

    temp_file = Tempfile.new([ "statement_#{statement.id}", File.extname(statement.file.filename.to_s) ])
    begin
      temp_file.binmode
      temp_file.write(statement.file.download)
      temp_file.rewind

      text = TextExtractor.extract(temp_file.path)

      if text.to_s.strip.empty?
        statement.update(status: "error", processed_at: Time.current)
        Rails.logger.error("StatementIngestJob: no extractable text (invalid or scanned PDF)")
        return
      end

      parsed = nil

      if ai_enabled?
        begin
          parsed = Ai::PostProcessor.new.call(
            raw_text: text,
            bank_name: statement.bank_account.bank_name,
            account_number: statement.bank_account.account_number
          )
        rescue => e
          Rails.logger.warn("AI parse failed: #{e.message}, falling back to deterministic parser")
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

      normalize_parsed!(parsed)  # <-- ensure budgeting type is income/expense

      statement.update(
        status: "parsed",
        processed_at: Time.current,
        parsed_json: parsed
      )
    rescue => e
      statement.update(status: "error")
      Rails.logger.error("StatementIngestJob failed for #{statement&.id}: #{e.message}\n#{e.backtrace.join("\n")}")
    ensure
      temp_file.close!
    end
  end

  private

  def ai_enabled?
    ENV.fetch("AI_API_KEY", "").strip != "" unless Rails.env.test?
  end

  def normalize_parsed!(hash)
    return unless hash.is_a?(Hash) && hash["transactions"].is_a?(Array)

    hash["transactions"].each do |t|
      amt = case t["amount"]
      when String then t["amount"].to_s.tr(",", "").to_f
      else t["amount"].to_f
      end
      raw_type = t["type"].to_s.downcase.strip

      # Keep original bank meaning if provided in type
      t["bank_entry_type"] = raw_type if %w[credit debit].include?(raw_type)

      # Coerce canonical budgeting type
      t["type"] = amt < 0 ? "expense" : "income"

      # Clean bank_entry_type to credit/debit or nil
      t["bank_entry_type"] =
        case t["bank_entry_type"].to_s.downcase.strip
        when "credit", "cr" then "credit"
        when "debit", "dr"  then "debit"
        else nil
        end
    end
  end
end
