# app/services/pdf_parser/banorte_savings_account.rb
module PdfParser
  class BanorteSavingsAccount < Base
    include MerchantExtraction

    DATE_PATTERN = /^(\d{2})-([A-Z]{3})-(\d{2})/i
    TRANSACTIONS_START = /DETALLE\s*DE\s*MOVIMIENTOS/i
    TRANSACTIONS_END = /OTROS|CARGOS\s*OBJETADOS|Cargos\s*Objetados|GAT\s*NOMINAL/i

    SKIP_PATTERNS = [
      /^FECHA\s+DESCRIPCIÓN/i, /^Nomina\s*Banorte/i, /^SALDO\s*ANTERIOR$/i,
      /^\s*$/, /MONTO\s*DEL?\s*DEPOSITO/i, /MONTO\s*DEL?\s*RETIRO/i
    ].freeze

    DEPOSIT_KEYWORDS = /DEPOSITO|TRASPASO.*DEL|TRANSFERENCIA.*RECIBIDA/i
    WITHDRAWAL_KEYWORDS = /COMPRA|RETIRO|TRASPASO.*AL|PAGO|TRANSFERENCIA.*ENVIADA|SPEI.*BCO:/i

    def parse(text)
      lines = split_lines(text)
      transaction_lines = extract_section(lines, TRANSACTIONS_START, TRANSACTIONS_END)
      transactions = parse_transactions(transaction_lines)
      summary_data = extract_financial_summary(lines)

      build_result(
        transactions: transactions,
        opening_balance: summary_data[:opening_balance],
        closing_balance: summary_data[:closing_balance],
        summary: summary_data[:summary]
      )
    end

    private

    def parse_transactions(lines)
      transactions = []
      current_transaction = nil
      continuation_lines = []

      lines.each do |line|
        next if should_skip_line?(line, SKIP_PATTERNS)

        date_match = line.match(DATE_PATTERN)

        if date_match
          if current_transaction
            finalize_description(current_transaction, continuation_lines)
            transactions << current_transaction unless skip_transaction?(current_transaction)
          end
          current_transaction = parse_transaction_line(line, date_match)
          continuation_lines = []
        elsif current_transaction && line.strip.length > 0
          continuation_lines << line.strip
        end
      end

      if current_transaction
        finalize_description(current_transaction, continuation_lines)
        transactions << current_transaction unless skip_transaction?(current_transaction)
      end

      transactions
    end

    def parse_transaction_line(line, date_match)
      date = normalize_spanish_date(date_match[1], date_match[2], date_match[3])
      amounts = line.scan(/([\d,]+\.\d{2})/)
      return if amounts.length < 2

      amount_value = amounts[-2][0].gsub(",", "").to_f
      description_part = line.sub(DATE_PATTERN, "").strip
      amount, type = determine_amount_and_type(description_part, amount_value)
      description = clean_description(description_part)

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

    def determine_amount_and_type(description, amount_value)
      if description.match?(DEPOSIT_KEYWORDS)
        [amount_value, "income"]
      elsif description.match?(WITHDRAWAL_KEYWORDS)
        [-amount_value, "variable_expense"]
      else
        [amount_value, "income"]
      end
    end

    def clean_description(text)
      text.gsub(/([\d,]+\.\d{2})/, "")
        .gsub(/SPEI\d+=REFERENCIA/, " SPEI ")
        .gsub(/CTA\/CLABE:\d+,?/, "")
        .gsub(/BEC\s*SPEI\s*BCO:\d+/, "")
        .gsub(/BENEF:\w+\([^)]+\),?/, "")
        .gsub(/CVERASTREO:\s*\S+/, "")
        .gsub(/RFC:\w*/, "")
        .gsub(/IVA:\.\d/, "")
        .gsub(/HORALIQ:\d{2}:\d{2}:\d{2}/, "")
        .gsub(/BBVAMEXICO|STP/, "")
        .gsub(/DATONOVERIFPORESTAINST/, "")
        .gsub(/AL?R\.F\.C\.\s*\w+/, "")
        .gsub(/\s+/, " ")
        .gsub(/,\s*$/, "")
        .strip
    end

    def finalize_description(transaction, continuation_lines)
      return if continuation_lines.empty?

      full_desc = (transaction["description"] || "").dup
      continuation_lines.each do |line|
        next if line.match?(/^[\dA-Z]+P\d+\d{12,}|^RFC:|^IVA:|^HORALIQ:/)

        cleaned = clean_description(line)
        full_desc += " #{cleaned}" if cleaned.length > 2
      end
      transaction["description"] = full_desc.gsub(/\s+/, " ").strip
    end

    def extract_reference(line)
      match = line.match(/CVERASTREO:\s*(\S+)/) || line.match(/(\d{10,})/)
      match&.[](1)
    end

    def skip_transaction?(transaction)
      return true if transaction.nil?

      desc = transaction["description"].to_s.upcase
      desc.include?("SALDO") && desc.include?("ANTERIOR")
    end

    def extract_financial_summary(lines)
      opening_balance = closing_balance = nil
      extras = {}

      lines.each do |line|
        normalized = line.gsub(/\s+/, "").downcase

        if normalized.include?("saldoinicialdelperiodo") || normalized.include?("saldoanterior")
          opening_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("saldoactual") || normalized.include?("saldoalcorte")
          closing_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("totaldedepósitos") || normalized.include?("totaldedepositos")
          extras[:total_deposits] ||= extract_amount_from_text(line)
        elsif normalized.include?("totalderetiros")
          extras[:total_withdrawals] ||= extract_amount_from_text(line)
        end
      end

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: build_debit_summary(
          bank_name: "Banorte",
          opening_balance: opening_balance,
          closing_balance: closing_balance,
          **extras
        )
      }
    end
  end
end
