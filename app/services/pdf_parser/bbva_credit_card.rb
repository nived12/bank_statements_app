# app/services/pdf_parser/bbva_credit_card.rb
module PdfParser
  class BbvaCreditCard < Base
    def parse(text, context: {})
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)

      # Check if this is the new format (July 2024+)
      if new_format_detected?(text)
        # Use new format parser for July 2024+ statements
        NewBbvaCreditCard.new.parse(text)
      else
        # Use legacy format parser for older statements
        OldBbvaCreditCard.new.parse(text)
      end
    end

    private

    def new_format_detected?(text)
      # Check for new format indicators based on actual transaction patterns

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
