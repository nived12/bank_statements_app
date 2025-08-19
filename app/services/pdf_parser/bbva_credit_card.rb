# app/services/pdf_parser/bbva_credit_card.rb
module PdfParser
  class BbvaCreditCard < Base
    def parse(text, context: {})
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)

      # Check if this is the new format (July 2024+)
      if is_new_format?(lines)
        puts "Detected new BBVA format (July 2024+), using new parser"
        NewBbvaCreditCard.new.parse(text, context: context)
      else
        puts "Using legacy BBVA format parser"
        OldBbvaCreditCard.new.parse(text, context: context)
      end
    end

    private

    def is_new_format?(lines)
      # Check for new format indicators based on actual transaction patterns
      text = lines.join(" ")

      # Look for the new format transaction patterns
      new_format_indicators = [
        /\d{2}-[a-z]{3}-\d{4}\s+\d{2}-[a-z]{3}-\d{4}/,  # Double date format
        /[+]\s*\$[\d,]+\.\d{2}/,                          # Positive amounts with +$
        /USD\s+\$[\d,]*\.?\d*\s+TIPO DE CAMBIO/           # USD conversion info
      ]

      new_format_indicators.any? { |pattern| text.match?(pattern) }
    end
  end
end
