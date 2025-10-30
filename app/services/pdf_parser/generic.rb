# app/services/pdf_parser/generic.rb
module PdfParser
  class Generic < Base
    DATE_RX = /\A(?<date>\d{2}[\/\-]\d{2}[\/\-]\d{4})/
    AMOUNT_RX_END = /(?<amount>\(?[-+]?\d[\d.,]*\)?)\s*\z/

    def parse(text)
      # Parse with generic parsing logic
      parse_generic(text)
    end

    private

    def parse_generic(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank
      transactions = []

      lines.each do |line|
        date_m = line.match(DATE_RX)
        amt_m  = line.match(AMOUNT_RX_END)
        next unless date_m && amt_m

        date_iso  = normalize_date_ddmmyyyy(date_m[:date])
        amount_bd = parse_decimal(amt_m[:amount])
        next unless amount_bd

        description = line.dup
        description.sub!(DATE_RX, "")
        description.sub!(AMOUNT_RX_END, "")
        description = description.strip.gsub(/\s{2,}/, " ")

        amount_f = amount_bd.to_f
        transaction_type = amount_f.negative? ? "variable_expense" : "income"

        transactions << {
          "date" => date_iso,
          "description" => description,
          "amount" => amount_f.round(2),
          "transaction_type" => transaction_type,
          "merchant" => nil,
          "reference" => nil,
          "category" => "Uncategorized",
          "sub_category" => nil,
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
