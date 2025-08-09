module PdfParser
  class Generic < Base
    # Date must be at the START of the line: dd/mm/yyyy or dd-mm-yyyy
    DATE_RX = /\A(?<date>\d{2}[\/\-]\d{2}[\/\-]\d{4})/

    # Amount must be at the END of the line (handles (1,234.56), -1,234.56, 89.00, 1234)
    AMOUNT_RX_END = /(?<amount>\(?[-+]?\d[\d.,]*\)?)\s*\z/

    def parse(text, context: {})
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)
      transactions = []

      lines.each do |line|
        date_m = line.match(DATE_RX)
        amt_m  = line.match(AMOUNT_RX_END)
        next unless date_m && amt_m

        date_iso  = normalize_date_ddmmyyyy(date_m[:date])
        amount_bd = parse_decimal(amt_m[:amount])
        next unless amount_bd

        # Description = everything between the date at start and amount at end
        description = line.dup
        description.sub!(DATE_RX, "")
        description.sub!(AMOUNT_RX_END, "")
        description = description.strip.gsub(/\s{2,}/, " ")

        amount_f = amount_bd.to_f
        bank_entry_type = amount_f.negative? ? "debit" : "credit"
        type = amount_f.negative? ? "expense" : "income"

        transactions << {
          "date" => date_iso,
          "description" => description,
          "amount" => amount_f.round(2),
          "type" => type,                       # income | expense
          "bank_entry_type" => bank_entry_type, # credit | debit
          "merchant" => nil,
          "reference" => nil,
          "category" => "Uncategorized",
          "sub_category" => nil,
          "fixed_or_variable" => "variable",
          "raw_text" => line,
          "confidence" => 0.6
        }
      end

      {
        "opening_balance" => nil,
        "closing_balance" => nil,
        "transactions" => transactions
      }
    end
  end
end
