# app/services/pdf_parser/nu_savings_account.rb
module PdfParser
  class NuSavingsAccount < Base
    include MerchantExtraction

    # Date pattern: DD MMM YYYY (e.g., 31 JUL 2025)
    DATE_PATTERN = /^(\d{1,2})\s+([A-Z]{3})\s+(\d{4})/i

    # Amount pattern: +$X,XXX.XX or -$X,XXX.XX
    AMOUNT_PATTERN = /([+\-])\s*\$\s*([\d,]+\.\d{2})\s*$/

    # Spanish month mapping
    MONTH_MAP = {
      "ENE" => "01", "FEB" => "02", "MAR" => "03", "ABR" => "04",
      "MAY" => "05", "JUN" => "06", "JUL" => "07", "AGO" => "08",
      "SEP" => "09", "OCT" => "10", "NOV" => "11", "DIC" => "12"
    }.freeze

    # Section markers
    TRANSACTIONS_START = /Detalle\s+de\s+movimientos\s+en\s+tu\s+cuenta/i
    CAJITAS_SECTION = /Detalle\s+de\s+movimientos\s+de\s+tus\s+cajitas/i
    SECTION_END = /Con\s+estos\s+movimientos.*saldo\s+promedio/i

    # Skip patterns
    SKIP_PATTERNS = [
      /^FECHA/i,
      /^DEL\s+\d/i,
      /MONTO\s+EN\s+PESOS/i,
      /^\s*$/,
      /^Nu\s+México/i,
      /Teléfono:/i,
      /^\d+\s+de\s+\d+$/  # Page numbers like "2 de 7"
    ].freeze

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Parse main account transactions only (skip cajitas to avoid duplicates)
      transactions = parse_account_transactions(lines)

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

    def parse_account_transactions(lines)
      transactions = []
      in_section = false
      current_transaction = nil
      continuation_lines = []

      lines.each do |line|
        # Start of account transactions section
        if line.match?(TRANSACTIONS_START)
          in_section = true
          next
        end

        # Stop at cajitas section or end marker (skip cajitas to avoid duplicates)
        if line.match?(CAJITAS_SECTION) || line.match?(SECTION_END)
          if current_transaction
            transactions << finalize_transaction(current_transaction, continuation_lines)
          end
          in_section = false
          break
        end

        next unless in_section

        # Skip headers and irrelevant lines
        next if SKIP_PATTERNS.any? { |pattern| line.match?(pattern) }

        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        if date_match
          # Save previous transaction
          if current_transaction
            transactions << finalize_transaction(current_transaction, continuation_lines)
          end

          if amount_match
            # This line has both date and amount
            current_transaction = parse_transaction_line(line, date_match, amount_match)
            continuation_lines = []
          else
            # Date line without amount - this is a "Depósito en Cajita" type line
            # Start tracking for potential multi-line description
            current_transaction = {
              "date" => normalize_date(date_match[1], date_match[2], date_match[3]),
              "description" => extract_description_from_date_line(line, date_match),
              "amount" => nil,
              "transaction_type" => nil,
              "merchant" => nil,
              "reference" => nil,
              "raw_text" => line
            }
            continuation_lines = []
          end
        elsif current_transaction
          # Continuation line
          if amount_match && current_transaction["amount"].nil?
            # This continuation line has the amount
            amount_value, transaction_type = parse_amount(amount_match)
            current_transaction["amount"] = sprintf("%.2f", amount_value)
            current_transaction["transaction_type"] = transaction_type

            # Add any description from this line
            desc_part = line.sub(AMOUNT_PATTERN, "").strip
            if desc_part.length > 2
              continuation_lines << desc_part
            end
          else
            # Regular continuation line
            continuation_lines << line
          end
        end
      end

      # Don't forget the last transaction
      if current_transaction
        transactions << finalize_transaction(current_transaction, continuation_lines)
      end

      # Note: Cajita movements are internal transfers but represent actual fund movements
      # in the Nu account, so we keep them all
      transactions
    end

    def parse_transaction_line(line, date_match, amount_match)
      date = normalize_date(date_match[1], date_match[2], date_match[3])
      amount_value, transaction_type = parse_amount(amount_match)

      description = extract_description_from_date_line(line, date_match)
      description = description.sub(AMOUNT_PATTERN, "").strip

      {
        "date" => date,
        "description" => description,
        "amount" => sprintf("%.2f", amount_value),
        "transaction_type" => transaction_type,
        "merchant" => nil,
        "reference" => nil,
        "raw_text" => line
      }
    end

    def extract_description_from_date_line(line, date_match)
      # Remove date from line
      date_str = "#{date_match[1]} #{date_match[2]} #{date_match[3]}"
      line.sub(date_str, "").strip
    end

    def parse_amount(amount_match)
      sign = amount_match[1]
      amount_value = amount_match[2].gsub(",", "").to_f

      if sign == "+"
        [amount_value, "income"]
      else
        [-amount_value, "variable_expense"]
      end
    end

    def finalize_transaction(transaction, continuation_lines)
      return if transaction["amount"].nil?

      # Build full description from continuation lines
      if continuation_lines.any?
        full_desc = [transaction["description"]]

        continuation_lines.each do |line|
          # Skip obvious footer/header lines
          next if line.match?(/Nu\s+México|Teléfono:|^\d+\s+de\s+\d+$/)
          next if line.length < 3

          full_desc << line
        end

        transaction["description"] = full_desc.join(" ").gsub(/\s+/, " ").strip
      end

      # Extract reference from description
      transaction["reference"] = extract_reference(transaction["description"])

      # Extract merchant
      transaction["merchant"] = extract_merchant(transaction["description"])

      # Clean up description - remove tracking numbers and technical details
      transaction["description"] = clean_description(transaction["description"])

      transaction
    end

    def internal_transfer?(transaction)
      desc = transaction["description"].to_s.downcase
      # Skip "Depósito en Cajita" lines as they're just internal transfers
      desc.include?("depósito en cajita") || desc.include?("deposito en cajita")
    end

    def extract_reference(description)
      # Look for SPEI tracking numbers
      if match = description.match(/Clave\s+de\s+rastreo\s+(\S+)/i)
        return match[1].gsub(",", "")
      end

      nil
    end

    def clean_description(description)
      # Remove verbose SPEI details but keep the essential info
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

      # If description is now too short, use a generic one
      desc.length < 5 ? "SPEI Transfer" : desc
    end

    def normalize_date(day, month, year)
      month_num = MONTH_MAP[month.upcase]
      return unless month_num

      sprintf("%s-%s-%02d", year, month_num, day.to_i)
    end

    def extract_financial_summary(lines)
      summary = {
        "statement_type" => "debit",
        "bank_name" => "Nu"
      }

      opening_balance = nil
      closing_balance = nil
      total_deposits = nil
      total_expenses = nil

      lines.each do |line|
        standardized = line.gsub(/\s+/, "").downcase

        # Opening balance
        if standardized.include?("saldoinicial")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            opening_balance = match[1].gsub(",", "").to_f
          end
        end

        # Closing balance - look for various patterns
        if standardized.include?("saldoalgenerarestestadodecuenta") ||
           standardized.include?("saldofinal") ||
           line.match?(/Saldo\s+al\s+generar\s+este\s+estado\s+de\s+cuenta/i)
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            closing_balance = match[1].gsub(",", "").to_f
          end
        end

        # Total deposits
        if standardized.match?(/^depósitos$|^depositos$/) ||
           (standardized.include?("depósitos") && !standardized.include?("detalle"))
          if match = line.match(/\+?\s*\$?\s*([\d,]+\.\d{2})/)
            total_deposits = match[1].gsub(",", "").to_f
          end
        end

        # Total expenses/gastos
        if standardized.match?(/^gastos$/)
          if match = line.match(/-?\s*\$?\s*([\d,]+\.\d{2})/)
            total_expenses = match[1].gsub(",", "").to_f
          end
        end
      end

      summary["opening_balance"] = opening_balance
      summary["closing_balance"] = closing_balance
      summary["total_deposits"] = total_deposits
      summary["total_withdrawals"] = total_expenses

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: summary
      }
    end
  end
end
