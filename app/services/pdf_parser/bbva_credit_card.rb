# app/services/pdf_parser/bbva_credit_card.rb
module PdfParser
  class BbvaCreditCard < Base
    # New format indicators for July 2024+ BBVA credit card statements
    NEW_FORMAT_INDICATORS = [
      /CARGOS\s*,?\s*COMPRAS\s+Y\s+ABONOS\s+REGULARES\s*\(?\s*NO\s+A\s+MESES\s*\)?/i,
      /COMPRAS\s+Y\s+CARGOS\s+DIFERIDOS\s+A\s+MESES\s+SIN\s+INTERESES/i,
      /DISTRIBUCIÓN\s+DE\s+TU\s+ÚLTIMO\s+PAGO/i
    ].freeze

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Check if this is the new format (July 2024+)
      if new_format_detected?(lines)
        # Use new format parser for July 2024+ statements
        result = NewBbvaCreditCard.call(text)
        result.success? ? result.payload : nil
      else
        # Use legacy format parser for older statements
        result = OldBbvaCreditCard.call(text)
        result.success? ? result.payload : nil
      end
    end

    private

    def new_format_detected?(lines)
      # Check for new format indicators based on actual transaction patterns
      NEW_FORMAT_INDICATORS.any? { |pattern| lines.any? { |line| line.match?(pattern) } }
    end
  end
end
