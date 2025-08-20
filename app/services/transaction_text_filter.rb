# app/services/transaction_text_filter.rb
class TransactionTextFilter
  def self.filter_for_transactions(text, bank_name: nil)
    # Clean corrupted text first
    text = clean_corrupted_text(text)

    bank_type = detect_bank_type(bank_name)
    patterns = get_patterns_for_bank(bank_type)

    # Handle PDFs that don't have proper line breaks - split on multiple spaces or actual line breaks
    lines = if text.include?("\n")
              text.split("\n")
    else
              # For PDF text without line breaks, we need to reconstruct the lines
              # Look for transaction patterns and split accordingly
              reconstruct_lines_from_pdf_text(text)
    end

    filtered_lines = []

    lines.each do |line|
      line = line.strip
      next if line.empty?

      # Always filter out balance lines regardless of other content
      if line.match?(/^Saldo (Promedio|Final):\s*[\d,]+\.\d{2}$/i)
        next
      end

      if should_filter_line?(line, patterns[:non_transaction], patterns[:strong])
        next
      elsif should_keep_line?(line, patterns[:transaction], patterns[:codes], bank_type)
        filtered_lines << line
      elsif is_transaction_continuation?(line, filtered_lines, bank_type)
        filtered_lines << line
      elsif is_potential_transaction_line?(line, bank_type)
        filtered_lines << line
      else
        next
      end
    end

    # Join lines back together, but preserve the line structure
    result = filtered_lines.join("\n")

    # If we're dealing with PDF text without line breaks, we need to preserve the structure
    if !text.include?("\n")
      # For PDF text without line breaks, we need to preserve the structure
      # The lines were already reconstructed properly, so join with newlines
      result = filtered_lines.join("\n")
    end

    result
  end

  # Reconstruct lines from PDF text that doesn't have proper line breaks
  def self.reconstruct_lines_from_pdf_text(text)
    lines = []
    current_line = ""

    # Split on multiple spaces to get potential line breaks
    parts = text.split(/\s{3,}/)

    parts.each do |part|
      part = part.strip
      next if part.empty?

      # If this part looks like it could be the start of a new transaction line
      if part.match?(/\d{2}-[a-z]{3}-\d{4}/) || part.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
        # Save the previous line if it exists
        lines << current_line.strip if current_line.strip.length > 0
        current_line = part
      else
        # This is a continuation of the current line
        current_line += " " + part
      end
    end

    # Add the last line
    lines << current_line.strip if current_line.strip.length > 0

    lines
  end

  # Clean corrupted text by removing invalid characters
  def self.clean_corrupted_text(text)
    return text unless text.is_a?(String)

    # Remove invalid ASCII control characters (0-31, except 9, 10, 13)
    text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

    # Remove other problematic characters that might cause AI parsing issues
    text = text.gsub(/[▯]/, "")  # Remove placeholder characters
    text = text.gsub(/\xEF\xBF\xBD/, "")  # Remove replacement character

    # Normalize line endings
    text = text.gsub(/\r\n/, "\n").gsub(/\r/, "\n")

    # Remove excessive whitespace
    text = text.gsub(/\n\s*\n\s*\n/, "\n\n")

    text
  end

  def self.extract_headers(text, bank_name: nil)
    bank_type = detect_bank_type(bank_name)
    header_config = BankStatementConfig.get_header_extraction(bank_type)

    headers = {}
    header_config.each do |category, patterns|
      headers[category] = []
      patterns.each do |pattern|
        matches = text.scan(/#{pattern}\s*(.+)/i)
        headers[category].concat(matches.flatten.map(&:strip))
      end
    end

    # Clean up headers - remove dollar signs and common prefixes
    headers.each do |category, values|
      headers[category] = values.map do |value|
        value.gsub(/\$/, "").gsub(/^En el Periodo \d+ \w+ al \d+ \w+:\s*/, "")
      end
    end

    headers
  end

  def self.extract_financial_data(text, bank_name: nil)
    bank_type = detect_bank_type(bank_name)
    extractor = FinancialDataExtractor.new(bank_type)
    extractor.extract_financial_data(text)
  end

  private

  def self.detect_bank_type(bank_name)
    return "generic" unless bank_name

    bank_name_lower = bank_name.downcase
    case bank_name_lower
    when /bbva|bancomer/
      "bbva"
    when /banamex/
      "banamex"
    when /banorte/
      "banorte"
    when /santander/
      "santander"
    when /hsbc/
      "hsbc"
    when /scotiabank/
      "scotiabank"
    else
      "generic"
    end
  end

  def self.get_patterns_for_bank(bank_type)
    non_transaction = BankStatementConfig.get_non_transaction_patterns(bank_type)
    transaction = BankStatementConfig.get_transaction_patterns(bank_type)
    codes = BankStatementConfig.get_transaction_codes(bank_type)

    # Fallback to generic patterns if no bank-specific ones found
    if non_transaction.empty? && transaction.empty?
      non_transaction = get_generic_non_transaction_patterns
      transaction = get_generic_transaction_patterns
    end

    {
      non_transaction: non_transaction,
      transaction: transaction,
      codes: codes,
      strong: get_strong_patterns
    }
  end

  def self.get_strong_patterns
    [
      /^ESTADO DE CUENTA/i,
      /^BANORTE$/i,
      /^BANCO/i,
      /^PAGINA \d+\/\d+/i,
      /^INFORMACIÓN DEL PERIODO/i,
      /^Producto:/i,
      /^Saldo anterior:/i,
      /^Saldo al corte:/i,
      /^Saldo Final:/i,
      /^Saldo Promedio:/i,
      /^Intereses devengados:/i,
      /^Saldo no disponible al día:/i,
      /^Advertencia:/i,
      /Saldo Promedio:\s*[\d,]+\.\d{2}/i,
      /Saldo Final:\s*[\d,]+\.\d{2}/i,
      # Additional patterns to catch balance lines that might not be caught by bank-specific patterns
      /^Saldo Promedio:\s*[\d,]+\.\d{2}$/i,
      /^Saldo Final:\s*[\d,]+\.\d{2}$/i
    ]
  end

  def self.should_filter_line?(line, non_transaction_patterns, strong_patterns)
    return false unless non_transaction_patterns.any? { |pattern| line.match?(/#{pattern}/i) }

    # Strong patterns always filter out
    return true if strong_patterns.any? { |pattern| line.match?(pattern) }

    # If line matches non-transaction patterns, filter it out
    # (This is more strict - non-transaction patterns take precedence)
    true
  end

  def self.has_transaction_info?(line)
    # Check for date patterns (including BBVA credit card format)
    return true if line.match?(/\d{2}\/[A-Z]{3}/) ||
                   line.match?(/\d{2}-\d{2}-\d{4}/) ||
                   line.match?(/\d{2}-[A-Z]{3}-\d{2}/) ||
                   line.match?(/\d{2}\/\d{2}\/\d{2}/)  # BBVA credit card format

    # Check for amount patterns (including BBVA new format with + and -)
    return true if line.match?(/[\d,]+\.\d{2}/) ||
                   line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)  # BBVA new format: + $400.00, - $226.00

    # Check for BBVA credit card specific patterns
    return true if line.match?(/IMPORTE CARGOS|IMPORTE ABONOS|FECHA AUTORIZACION|FECHA APLICACION/)

    # Check for BBVA new format patterns (July 2024+)
    return true if line.match?(/\d{2}-[a-z]{3}-\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)

    false
  end

  def self.should_keep_line?(line, transaction_patterns, transaction_codes, bank_type)
    # Check if line contains transaction keywords
    return true if transaction_patterns.any? { |pattern| line.match?(/#{pattern}/i) }

    # Check if line contains transaction codes
    return true if transaction_codes.any? { |code| line.include?(code) }

    # Check for transaction info
    has_transaction_info?(line)
  end

  def self.is_transaction_continuation?(line, previous_lines, bank_type)
    return false if previous_lines.empty?

    last_line = previous_lines.last
    has_date = ->(text) {
      text.match?(/\d{2}\/[A-Z]{3}/) ||
      text.match?(/\d{2}-[A-Z]{3}-\d{2}/) ||
      text.match?(/\d{2}\/\d{2}\/\d{2}/)  # BBVA credit card format
    }
    has_amount = ->(text) { text.match?(/[\d,]+\.\d{2}/) }

    case bank_type
    when "bbva"
      # If last line has date but no amount, this line might be continuation
      if has_date.call(last_line) && !has_amount.call(last_line)
        return !has_date.call(line)
      end

      # If last line has transaction code but no amount, this line might be continuation
      codes = BankStatementConfig.get_transaction_codes(bank_type)
      if codes.any? { |code| last_line.include?(code) } && !has_amount.call(last_line)
        return !has_date.call(line)
      end

      # For BBVA credit card, check if line contains IMPORTE CARGOS/ABONOS
      if line.match?(/IMPORTE CARGOS|IMPORTE ABONOS/)
        return true
      end

    when "banorte"
      # If last line has date but no amount, this line might be continuation
      if has_date.call(last_line) && !has_amount.call(last_line)
        return !has_date.call(line)
      end

      # If last line has transaction keywords but no amount, this line might be continuation
      keywords = BankStatementConfig.get_transaction_patterns(bank_type)
      if keywords.any? { |keyword| last_line.match?(/#{keyword}/i) } && !has_amount.call(last_line)
        return !has_date.call(line)
      end

    else
      # Generic continuation logic
      if has_date.call(last_line) && !has_amount.call(last_line)
        return !has_date.call(line)
      end
    end

    false
  end

  def self.is_potential_transaction_line?(line, bank_type)
    case bank_type
    when "bbva"
      # For BBVA, be more permissive with lines that might contain transaction data
      return true if line.match?(/\d{2}\/\d{2}\/\d{2}/)  # Date pattern
      return true if line.match?(/[\d,]+\.\d{2}/)  # Amount pattern
      return true if line.match?(/IMPORTE CARGOS|IMPORTE ABONOS/)  # Amount columns
      return true if line.match?(/FECHA AUTORIZACION|FECHA APLICACION/)  # Date columns
      return true if line.match?(/CONCEPTO|REFERENCIA/)  # Transaction info columns

      # Check for common transaction descriptions
      return true if line.match?(/BMOVIL|SIX PREMIER|ANUALIDAD|NETFLIX|AMAZON|GOOGLE|YOUTUBE/)

    else
      # For other banks, use generic logic
      return has_transaction_info?(line)
    end

    false
  end

  def self.get_generic_non_transaction_patterns
    [
      "Estado de Cuenta",
      "PAGINA",
      "No\\. Cuenta",
      "No\\. Cliente",
      "Saldo Promedio",
      "Saldo de Liquidación",
      "Días del Periodo",
      "Tasa Bruta Anual"
    ]
  end

  def self.get_generic_transaction_patterns
    [
      "PAGO",
      "TRANSFERENCIA",
      "DEPOSITO",
      "RETIRO",
      "NOMINA",
      "INTERESES",
      "SPEI",
      "TRASPASO"
    ]
  end
end
