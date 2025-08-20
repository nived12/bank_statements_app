# app/services/pdf_parser/bbva_credit_card.rb
module PdfParser
  class BbvaCreditCard < Base
    def parse(text, context: {})
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)

      # Check if this is the new format (July 2024+)
      if new_format_detected?(text)
        # Use new format parser for July 2024+ statements
        NewBbvaCreditCard.new.parse(text, context: context)
      else
        # Use legacy format parser for older statements
        OldBbvaCreditCard.new.parse(text, context: context)
      end
    end

    private

    def new_format_detected?(text)
      # Check for new format indicators based on actual transaction patterns

      # Convert to lines if text is a string
      lines = text.is_a?(String) ? text.split("\n") : text
      lines = lines.map(&:strip).reject(&:empty?) if lines.is_a?(Array)

      # Look for the new format transaction patterns
      new_format_indicators = [
        /CARGOS, COMPRAS Y ABONOS REGULARES \(NO A MESES\)/i,  # New format section headers
        /COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES/i,
        /RESUMEN DE CARGOS Y ABONOS DEL PERIODO/i,
        /DISTRIBUCIÓN DE TU ÚLTIMO PAGO/i,
        /\d{2}-[a-z]{3}-\d{4}\s+\d{2}-[a-z]{3}-\d{4}/,  # Double date format (two consecutive dates)
        /[+]\s*\$[\d,]+\.\d{2}/,                          # Positive amounts with +$
        /USD\s+\$[\d,]*\.?\d*\s+TIPO DE CAMBIO/           # USD conversion info
      ]

      new_format_indicators.any? { |pattern| lines.any? { |line| line.match?(pattern) } }
    end

    def is_new_format?(lines)
      text = lines.join("\n")
      new_format_detected?(text)
    end
  end
end
