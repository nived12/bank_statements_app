# app/services/pdf_parser/banorte_savings_account.rb
module PdfParser
  class BanorteSavingsAccount < Base
    include MerchantExtraction

    # Date pattern: DD-MMM-YY (e.g., 10-JUN-25)
    DATE_PATTERN = /^(\d{2})-([A-Z]{3})-(\d{2})/i

    # Spanish month mapping
    MONTH_MAP = {
      "ENE" => "01", "FEB" => "02", "MAR" => "03", "ABR" => "04",
      "MAY" => "05", "JUN" => "06", "JUL" => "07", "AGO" => "08",
      "SEP" => "09", "OCT" => "10", "NOV" => "11", "DIC" => "12"
    }.freeze

    # Section markers
    TRANSACTIONS_START = /DETALLE\s*DE\s*MOVIMIENTOS/i
    TRANSACTIONS_END = /OTROS|CARGOS\s*OBJETADOS|Cargos\s*Objetados|GAT\s*NOMINAL/i

    # Lines to skip
    SKIP_PATTERNS = [
      /^FECHA\s+DESCRIPCIÓN/i,
      /^Nomina\s*Banorte/i,
      /^SALDO\s*ANTERIOR$/i,
      /^\s*$/,
      /MONTO\s*DEL?\s*DEPOSITO/i,
      /MONTO\s*DEL?\s*RETIRO/i
    ].freeze

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Find the transactions section
      transaction_lines = extract_transaction_section(lines)

      # Parse transactions with multi-line support
      transactions = parse_transactions(transaction_lines)

      # Extract financial summary
      financial_summary = extract_financial_summary(lines)

      {
        "extraction_source" => "deterministic_parser",
        "transactions" => transactions,
        "opening_balance" => financial_summary[:opening_balance],
        "closing_balance" => financial_summary[:closing_balance],
        "financial_summaries" => financial_summary[:summary] ? [financial_summary[:summary]] : []
      }
    end

    private

    def extract_transaction_section(lines)
      section_lines = []
      in_section = false

      lines.each do |line|
        if line.match?(TRANSACTIONS_START)
          in_section = true
          next
        end

        break if in_section && line.match?(TRANSACTIONS_END)

        section_lines << line if in_section
      end

      section_lines
    end

    def parse_transactions(lines)
      transactions = []
      current_transaction = nil
      continuation_lines = []

      lines.each do |line|
        # Skip header and empty lines
        next if SKIP_PATTERNS.any? { |pattern| line.match?(pattern) }

        date_match = line.match(DATE_PATTERN)

        if date_match
          # Save previous transaction if exists
          if current_transaction
            current_transaction["description"] =
build_description(current_transaction["description"], continuation_lines)
            transactions << current_transaction unless skip_transaction?(current_transaction)
          end

          # Start new transaction
          current_transaction = parse_transaction_line(line, date_match)
          continuation_lines = []
        elsif current_transaction && line.strip.length > 0
          # This is a continuation line (starts with spaces or no date)
          continuation_lines << line.strip
        end
      end

      # Don't forget the last transaction
      if current_transaction
        current_transaction["description"] = build_description(current_transaction["description"], continuation_lines)
        transactions << current_transaction unless skip_transaction?(current_transaction)
      end

      transactions
    end

    def parse_transaction_line(line, date_match)
      date = normalize_date(date_match[1], date_match[2], date_match[3])

      # Extract amounts - Banorte uses positional columns
      # Format: FECHA DESCRIPCION DEPOSITO RETIRO SALDO
      # The amounts are at the end of the line, space-separated

      # Find all amounts in the line (comma thousands, period decimals)
      amounts = line.scan(/([\d,]+\.\d{2})/)

      return if amounts.empty?

      # The last amount is always SALDO (balance)
      # If there are 2 amounts: one is deposit/withdrawal, one is saldo
      # If there are 3 amounts: deposit, withdrawal, saldo (one of deposit/withdrawal is the amount)

      saldo = amounts.last[0].gsub(",", "").to_f

      # Determine if this is a deposit or withdrawal based on pattern
      description_part = line.sub(DATE_PATTERN, "").strip

      # Check for deposit keywords
      is_deposit = description_part.match?(/DEPOSITO|TRASPASO.*DEL|TRANSFERENCIA.*RECIBIDA/i)
      # Check for withdrawal keywords
      is_withdrawal = description_part.match?(/COMPRA|RETIRO|TRASPASO.*AL|PAGO|TRANSFERENCIA.*ENVIADA/i)

      # Extract the amount (second to last if available, otherwise calculate from context)
      if amounts.length >= 2
        amount_value = amounts[-2][0].gsub(",", "").to_f
      else
        # Only saldo available, skip this line (likely SALDO ANTERIOR)
        return
      end

      # Determine transaction type based on description patterns
      if is_deposit
        amount = amount_value
        transaction_type = "income"
      elsif is_withdrawal
        amount = -amount_value
        transaction_type = "variable_expense"
      else
        # Default: if second column has value, it's deposit; if third, it's withdrawal
        # We need to check position in the original line
        # Simpler: check if the description contains common expense patterns
        if description_part.match?(/SPEI.*BCO:|COMPRA|RETIRO|PAGO/i)
          amount = -amount_value
          transaction_type = "variable_expense"
        else
          amount = amount_value
          transaction_type = "income"
        end
      end

      # Extract description (everything after date, before amounts)
      description = extract_description(description_part)

      merchant = extract_merchant(description)

      {
        "date" => date,
        "description" => description,
        "amount" => sprintf("%.2f", amount),
        "transaction_type" => transaction_type,
        "merchant" => merchant,
        "reference" => extract_reference(line),
        "raw_text" => line
      }
    end

    def extract_description(text)
      # Remove amounts from text
      desc = text.gsub(/([\d,]+\.\d{2})/, "")

      # Clean up SPEI-specific formatting
      desc = desc.gsub(/SPEI\d+=REFERENCIA/, " SPEI ")
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

      # Clean up whitespace and special characters
      desc.gsub(/\s+/, " ").gsub(/,\s*$/, "").strip
    end

    def build_description(main_desc, continuation_lines)
      return main_desc if continuation_lines.empty?

      # Add relevant info from continuation lines
      full_desc = main_desc.dup
      continuation_lines.each do |line|
        # Skip lines that are just reference numbers or technical info
        next if line.match?(/^[\dA-Z]+P\d+\d{12,}/)
        next if line.match?(/^RFC:|^IVA:|^HORALIQ:/)

        cleaned = extract_description(line)
        full_desc += " #{cleaned}" if cleaned.length > 2
      end

      full_desc.gsub(/\s+/, " ").strip
    end

    def extract_reference(line)
      # Look for SPEI tracking numbers
      if match = line.match(/CVERASTREO:\s*(\S+)/)
        return match[1]
      end

      # Look for transaction numbers
      if match = line.match(/(\d{10,})/)
        return match[1]
      end

      nil
    end

    def normalize_date(day, month, year)
      month_num = MONTH_MAP[month.upcase]
      return unless month_num

      # Convert 2-digit year to 4-digit
      full_year = year.to_i < 50 ? "20#{year}" : "19#{year}"

      "#{full_year}-#{month_num}-#{day}"
    end

    def skip_transaction?(transaction)
      return true if transaction.nil?

      desc = transaction["description"].to_s.upcase
      # Skip SALDO ANTERIOR line (not a real transaction)
      desc.include?("SALDO") && desc.include?("ANTERIOR")
    end

    def extract_financial_summary(lines)
      summary = {
        "statement_type" => "debit",
        "bank_name" => "Banorte"
      }

      opening_balance = nil
      closing_balance = nil
      total_deposits = nil
      total_withdrawals = nil

      lines.each do |line|
        standardized = line.gsub(/\s+/, "").downcase

        # Opening balance
        if standardized.include?("saldoinicialdelperiodo") || standardized.include?("saldoanterior")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            opening_balance = match[1].gsub(",", "").to_f
          end
        end

        # Closing balance
        if standardized.include?("saldoactual") || standardized.include?("saldoalcorte")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            closing_balance = match[1].gsub(",", "").to_f
          end
        end

        # Total deposits
        if standardized.include?("totaldedepósitos") || standardized.include?("totaldedepositos")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            total_deposits = match[1].gsub(",", "").to_f
          end
        end

        # Total withdrawals
        if standardized.include?("totalderetiros")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            total_withdrawals = match[1].gsub(",", "").to_f
          end
        end
      end

      summary["opening_balance"] = opening_balance
      summary["closing_balance"] = closing_balance
      summary["total_deposits"] = total_deposits
      summary["total_withdrawals"] = total_withdrawals

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: summary
      }
    end
  end
end
