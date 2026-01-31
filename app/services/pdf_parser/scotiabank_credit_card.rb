# app/services/pdf_parser/scotiabank_credit_card.rb
module PdfParser
  class ScotiabankCreditCard < Base
    include MerchantExtraction

    # DD/MM DD/MM format (operation date, charge date)
    DATE_PATTERN = /(\d{2})\/(\d{2})\s+(\d{2})\/(\d{2})/
    # Scotiabank uses INVERTED signs: + = expense, - = income
    AMOUNT_PATTERN = /([+\-])\s*\$?\s*([\d,]+\.\d{2})\s*$/
    REGULAR_SECTION_START = /CARGOS,?\s*ABONOS\s*Y\s*COMPRAS\s*REGULARES/i
    DEFERRED_SECTION = /COMPRAS\s*Y\s*CARGOS\s*DIFERIDOS\s*A\s*MESES/i

    SKIP_PATTERNS = [
      /^i\.\s*Fecha/i, /^ii\.\s*Fecha/i, /^\s*operación\s*$/i, /^\s*cargo\s*$/i,
      /^Tarjeta\s+(Titular|Adicional)/i, /^Notas:/i, /^Número\s+de\s+tarjeta/i, /^\s*$/
    ].freeze

    def parse(text)
      lines = split_lines(text)
      @statement_year = extract_statement_year(lines)
      transactions = parse_transactions(lines)
      summary_data = extract_financial_summary(lines)

      build_result(
        transactions: transactions,
        opening_balance: summary_data[:opening_balance],
        closing_balance: summary_data[:closing_balance],
        summary: summary_data[:summary]
      )
    end

    private

    def extract_statement_year(lines)
      lines.each do |line|
        match = line.match(/(\d{4})\s+al\s+\d{2}-\w{3}-(\d{4})/) || line.match(/Periodo.*?(\d{4})/)
        return (match[2] || match[1]).to_i if match
      end
      Date.current.year
    end

    def parse_transactions(lines)
      transactions = []
      in_section = false
      current_transaction = nil
      continuation_lines = []

      lines.each do |line|
        if line.match?(REGULAR_SECTION_START)
          transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
          in_section = true
          current_transaction = nil
          continuation_lines = []
          next
        end

        if line.match?(DEFERRED_SECTION)
          transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
          in_section = false
          current_transaction = nil
          continuation_lines = []
          next
        end

        next unless in_section
        next if should_skip_line?(line, SKIP_PATTERNS)

        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        if date_match && amount_match
          transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
          current_transaction = parse_transaction_line(line, date_match, amount_match)
          continuation_lines = []
        elsif current_transaction && line.length > 2
          continuation_lines << line
        end
      end

      transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
      transactions.compact
    end

    def parse_transaction_line(line, date_match, amount_match)
      date = determine_date(date_match[3], date_match[4])
      amount, type = parse_inverted_signed_amount(amount_match[1], amount_match[2])
      description = clean_scotiabank_description(line)

      return if description.blank? || description.length < 4

      build_transaction(
        date: date,
        description: description,
        amount: amount,
        transaction_type: type,
        merchant: extract_merchant(description),
        reference: extract_reference(line),
        raw_text: line
      )
    end

    def clean_scotiabank_description(line)
      line.gsub(DATE_PATTERN, "")
        .gsub(AMOUNT_PATTERN, "")
        .gsub(/[A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3}/, "")
        .gsub(/[\d.]+\s*USD/, "")
        .gsub(/\s+/, " ")
        .strip
    end

    def finalize_transaction(transaction, continuation_lines)
      return unless transaction

      continuation_lines.each do |line|
        cleaned = line.gsub(/[A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3}/, "").strip
        transaction["description"] += " #{cleaned}" if cleaned.length >= 3
      end

      transaction["description"] = transaction["description"].gsub(/\s+/, " ").strip
      return if transaction["description"].blank? || transaction["description"].length < 4

      transaction["merchant"] = extract_merchant(transaction["description"])
      transaction
    end

    def extract_reference(line)
      match = line.match(/([A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3})/)
      match&.[](1)&.gsub(/\s+/, "")
    end

    def determine_date(day, month)
      month_int = month.to_i
      year = @statement_year
      year -= 1 if month_int == 12 && month_int >= 10
      normalize_ddmm_date(day, month, year)
    end

    def extract_financial_summary(lines)
      opening_balance = closing_balance = nil
      extras = {}

      lines.each do |line|
        normalized = line.gsub(/\s+/, "").downcase

        if normalized.include?("adeudodelperiodoanterior")
          opening_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("pagoparanogenerarintereses")
          closing_balance ||= extract_amount_from_text(line)
          extras[:payment_to_avoid_interest] ||= extract_amount_from_text(line)
        elsif normalized.include?("pagomínimo") && !normalized.include?("+")
          extras[:minimum_payment] ||= extract_amount_from_text(line)
        elsif normalized.include?("límitedecrédito") || normalized.include?("limitedecredito")
          extras[:credit_limit] ||= extract_amount_from_text(line)
        elsif normalized.include?("créditodisponible") || normalized.include?("creditodisponible")
          extras[:available_credit] ||= extract_amount_from_text(line)
        end
      end

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: build_credit_summary(
          bank_name: "Scotiabank",
          opening_balance: opening_balance,
          closing_balance: closing_balance,
          **extras
        )
      }
    end
  end
end
