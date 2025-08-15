# app/services/transaction_text_filter.rb
class TransactionTextFilter
  def self.filter_for_transactions(text, bank_name: nil)
    bank_type = detect_bank_type(bank_name)
    patterns = get_patterns_for_bank(bank_type)

    lines = text.split("\n")
    filtered_lines = []

    lines.each do |line|
      line = line.strip
      next if line.empty?

      if should_filter_line?(line, patterns[:non_transaction], patterns[:strong])
        next
      elsif should_keep_line?(line, patterns[:transaction], patterns[:codes], bank_type)
        filtered_lines << line
      elsif is_transaction_continuation?(line, filtered_lines, bank_type)
        filtered_lines << line
      end
    end

    filtered_lines.join("\n")
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
        value.gsub(/^\$/, "").gsub(/^En el Periodo \d+ \w+ al \d+ \w+:\s*/, "")
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
      /^Advertencia:/i
    ]
  end

  def self.should_filter_line?(line, non_transaction_patterns, strong_patterns)
    return false unless non_transaction_patterns.any? { |pattern| line.match?(/#{pattern}/i) }

    # Strong patterns always filter out
    return true if strong_patterns.any? { |pattern| line.match?(pattern) }

    # Check if line also contains transaction info
    !has_transaction_info?(line)
  end

  def self.has_transaction_info?(line)
    # Check for date patterns
    return true if line.match?(/\d{2}\/[A-Z]{3}/) ||
                   line.match?(/\d{2}-\d{2}-\d{4}/) ||
                   line.match?(/\d{2}-[A-Z]{3}-\d{2}/)

    # Check for amount patterns
    return true if line.match?(/[\d,]+\.\d{2}/)

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

  def self.is_transaction_continuation?(line, previous_lines, bank_type)
    return false if previous_lines.empty?

    last_line = previous_lines.last
    has_date = ->(text) { text.match?(/\d{2}\/[A-Z]{3}/) || text.match?(/\d{2}-[A-Z]{3}-\d{2}/) }
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
