# app/services/pdf_parser/nu_savings_account.rb
module PdfParser
  class NuSavingsAccount < Base
    include MerchantExtraction

    DATE_PATTERN = /^(\d{1,2})\s+([A-Z]{3})\s+(\d{4})/i
    AMOUNT_PATTERN = /([+\-])\s*\$\s*([\d,]+\.\d{2})\s*$/
    TRANSACTIONS_START = /Detalle\s+de\s+movimientos\s+en\s+tu\s+cuenta/i
    TRANSACTIONS_END = /Detalle\s+de\s+movimientos\s+de\s+tus\s+cajitas|Con\s+estos\s+movimientos.*saldo\s+promedio/i

    SKIP_PATTERNS = [
      /^FECHA/i, /^DEL\s+\d/i, /MONTO\s+EN\s+PESOS/i, /^\s*$/,
      /^Nu\s+México/i, /Teléfono:/i, /^\d+\s+de\s+\d+$/
    ].freeze

    def parse(text)
      lines = split_lines(text)
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

    def parse_transactions(lines)
      transactions = []
      in_section = false
      current_transaction = nil
      continuation_lines = []

      lines.each do |line|
        if line.match?(TRANSACTIONS_START)
          in_section = true
          next
        end

        if line.match?(TRANSACTIONS_END)
          transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
          break
        end

        next unless in_section
        next if should_skip_line?(line, SKIP_PATTERNS)

        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        if date_match
          transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction

          if amount_match
            current_transaction = parse_transaction_line(line, date_match, amount_match)
            continuation_lines = []
          else
            current_transaction = build_partial_transaction(line, date_match)
            continuation_lines = []
          end
        elsif current_transaction
          if amount_match && current_transaction["amount"].nil?
            amount_value, type = parse_signed_amount(amount_match[1], amount_match[2])
            current_transaction["amount"] = sprintf("%.2f", amount_value)
            current_transaction["transaction_type"] = type
            desc_part = line.sub(AMOUNT_PATTERN, "").strip
            continuation_lines << desc_part if desc_part.length > 2
          else
            continuation_lines << line
          end
        end
      end

      transactions << finalize_transaction(current_transaction, continuation_lines) if current_transaction
      transactions.compact
    end

    def parse_transaction_line(line, date_match, amount_match)
      date = normalize_spanish_date(date_match[1], date_match[2], date_match[3])
      amount_value, type = parse_signed_amount(amount_match[1], amount_match[2])
      description = extract_date_line_description(line, date_match).sub(AMOUNT_PATTERN, "").strip

      build_transaction(
        date: date,
        description: description,
        amount: amount_value,
        transaction_type: type,
        raw_text: line
      )
    end

    def build_partial_transaction(line, date_match)
      {
        "date" => normalize_spanish_date(date_match[1], date_match[2], date_match[3]),
        "description" => extract_date_line_description(line, date_match),
        "amount" => nil,
        "transaction_type" => nil,
        "merchant" => nil,
        "reference" => nil,
        "raw_text" => line
      }
    end

    def extract_date_line_description(line, date_match)
      date_str = "#{date_match[1]} #{date_match[2]} #{date_match[3]}"
      line.sub(date_str, "").strip
    end

    def finalize_transaction(transaction, continuation_lines)
      return if transaction.nil? || transaction["amount"].nil?

      if continuation_lines.any?
        full_desc = [transaction["description"]]
        continuation_lines.each do |line|
          next if line.match?(/Nu\s+México|Teléfono:|^\d+\s+de\s+\d+$/)
          next if line.length < 3

          full_desc << line
        end
        transaction["description"] = full_desc.join(" ").gsub(/\s+/, " ").strip
      end

      transaction["reference"] = extract_reference(transaction["description"])
      transaction["merchant"] = extract_merchant(transaction["description"])
      transaction["description"] = clean_nu_description(transaction["description"])
      transaction
    end

    def extract_reference(description)
      match = description.match(/Clave\s+de\s+rastreo\s+(\S+)/i)
      match&.[](1)&.gsub(",", "")
    end

    def clean_nu_description(description)
      desc = description
        .gsub(/Depósito\s+SPEI,\s+Hora:\s+\d{2}:\d{2}:\d{2},\s*/i, "")
        .gsub(/Recibido\s+de\s+(\w+)\./i, 'de \1')
        .gsub(/Del\s+cliente\s+/i, "")
        .gsub(/\(Dato\s+no\s+verificado\s+por\s+esta\s+institución\),?\s*/i, "")
        .gsub(/por\s+concepto\s+/i, "")
        .gsub(/De\s+la\s+cuenta\s+\d+\s+clabe,?\s*/i, "")
        .gsub(/Clave\s+de\s+rastreo\s+\S+,?\s*/i, "")
        .gsub(/Clave\s+de\s+referencia\s+\S+/i, "")
        .gsub(/\s+/, " ")
        .strip

      desc.length < 5 ? "SPEI Transfer" : desc
    end

    def extract_financial_summary(lines)
      opening_balance = closing_balance = nil
      extras = {}

      lines.each do |line|
        normalized = line.gsub(/\s+/, "").downcase

        if normalized.include?("saldoinicial")
          opening_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("saldoalgenerarestestadodecuenta") ||
              normalized.include?("saldofinal") ||
              line.match?(/Saldo\s+al\s+generar\s+este\s+estado\s+de\s+cuenta/i)
          closing_balance ||= extract_amount_from_text(line)
        elsif normalized.match?(/^depósitos$|^depositos$/) ||
              (normalized.include?("depósitos") && !normalized.include?("detalle"))
          extras[:total_deposits] ||= extract_amount_from_text(line)
        elsif normalized.match?(/^gastos$/)
          extras[:total_withdrawals] ||= extract_amount_from_text(line)
        end
      end

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: build_debit_summary(
          bank_name: "Nu",
          opening_balance: opening_balance,
          closing_balance: closing_balance,
          **extras
        )
      }
    end
  end
end
