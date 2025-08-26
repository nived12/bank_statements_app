# app/services/pdf_parser/bbva_savings_account.rb
module PdfParser
  class BbvaSavingsAccount < PdfParser::Base
    def parse(text, context: {})
      # Check if this is the new format (2025+)
      if new_format_detected?(text)
        # Use new format parser for 2025+ statements
        NewBbvaSavingsAccount.new.parse(text, context: context)
      else
        # Use legacy format parser for older statements (2021)
        OldBbvaSavingsAccount.new.parse(text, context: context)
      end
    end

    private

    def new_format_detected?(text)
      # Check for new format based on column positions, not transaction descriptions
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)

      # Find the header line that contains CARGOS and ABONOS
      header_line = lines.find { |line| line.include?("CARGOS") && line.include?("ABONOS") }
      return false unless header_line

      # Get the positions of CARGOS and ABONOS columns
      cargos_pos = header_line.index("CARGOS")
      abonos_pos = header_line.index("ABONOS")

      return false unless cargos_pos && abonos_pos

      # BBVA 2021 format: CARGOS at ~82, ABONOS at ~96 (difference: ~14)
      # BBVA 2025 format: CARGOS at ~83, ABONOS at ~96 (difference: ~13)
      # The key difference is that 2025 format has more structured headers

      # Check if this looks like the new format by examining the header structure
      # New format (2025+): "OPER LIQ DESCRIPCIÓN" (no "COD.")
      # Old format (2021): "OPER LIQ COD. DESCRIPCIÓN" (has "COD.")
      if header_line.include?("OPER") && header_line.include?("LIQ") && header_line.include?("DESCRIPCIÓN") && !header_line.include?("COD.")
        # This is the new format (2025+)
        true
      else
        # This is the old format (2021)
        false
      end
    end
  end
end
