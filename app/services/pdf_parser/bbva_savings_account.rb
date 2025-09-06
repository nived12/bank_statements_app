# app/services/pdf_parser/bbva_savings_account.rb
module PdfParser
  class BbvaSavingsAccount < Base
    def parse(text)
      # Check if this is the new format (2025+)
      result = if new_format_detected?(text)
        # Use new format parser for 2025+ statements
        NewBbvaSavingsAccount.call(text)
      else
        # Use legacy format parser for older statements (2021)
        OldBbvaSavingsAccount.call(text)
      end

      result.success? ? result.payload : nil
    end

    private

    def new_format_detected?(text)
      # Check for new format based on column positions, not transaction descriptions
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Find the header line that contains CARGOS and ABONOS
      header_line = lines.find { |line| line.include?("CARGOS") && line.include?("ABONOS") }
      return false unless header_line

      # Check if this looks like the new format by examining the header structure
      # New format (2024+): "OPER LIQ DESCRIPCIÓN" (no "COD.")
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
