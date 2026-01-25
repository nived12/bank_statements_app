# app/services/pdf_parser/scotiabank_credit_card.rb
module PdfParser
  class ScotiabankCreditCard < Base
    include MerchantExtraction

    # Date pattern: DD/MM (e.g., 23/12)
    DATE_PATTERN = /(\d{2})\/(\d{2})\s+(\d{2})\/(\d{2})/

    # Amount pattern: + or - followed by $X,XXX.XX
    # Note: Scotiabank uses INVERTED signs: + = expense, - = income/payment
    AMOUNT_PATTERN = /([+\-])\s*\$?\s*([\d,]+\.\d{2})\s*$/

    # Section markers - regular charges section
    REGULAR_SECTION_START = /CARGOS,?\s*ABONOS\s*Y\s*COMPRAS\s*REGULARES/i
    DEFERRED_SECTION = /COMPRAS\s*Y\s*CARGOS\s*DIFERIDOS\s*A\s*MESES/i

    # Lines to skip
    SKIP_PATTERNS = [
      /^i\.\s*Fecha/i,
      /^ii\.\s*Fecha/i,
      /^\s*operación\s*$/i,
      /^\s*cargo\s*$/i,
      /^Tarjeta\s+(Titular|Adicional)/i,
      /^Notas:/i,
      /^Número\s+de\s+tarjeta/i,
      /^\s*$/
    ].freeze

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Find the statement year from the period line
      @statement_year = extract_statement_year(lines)

      # Parse only regular charges section (skip deferred section)
      transactions = parse_regular_charges(lines)

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

    def extract_statement_year(lines)
      # Look for period line like "Periodo: 21-Dic-2024 al 20-Ene-2025"
      lines.each do |line|
        if match = line.match(/(\d{4})\s+al\s+\d{2}-\w{3}-(\d{4})/)
          return match[2].to_i  # Return the end year
        end
        if match = line.match(/Periodo.*?(\d{4})/)
          return match[1].to_i
        end
      end
      Date.current.year
    end

    def parse_regular_charges(lines)
      transactions = []
      in_regular_section = false
      current_description_lines = []
      current_transaction = nil

      lines.each do |line|
        # Start of regular charges section
        if line.match?(REGULAR_SECTION_START)
          # Save previous transaction if exists
          if current_transaction
            transactions << finalize_transaction(current_transaction, current_description_lines)
          end
          in_regular_section = true
          current_transaction = nil
          current_description_lines = []
          next
        end

        # Exit when we hit deferred section (don't process those)
        if line.match?(DEFERRED_SECTION)
          if current_transaction
            transactions << finalize_transaction(current_transaction, current_description_lines)
          end
          in_regular_section = false
          current_transaction = nil
          current_description_lines = []
          next
        end

        next unless in_regular_section

        # Skip header lines
        next if SKIP_PATTERNS.any? { |pattern| line.match?(pattern) }

        # Check if this is a new transaction line (has dates and amount)
        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        if date_match && amount_match
          # Save previous transaction
          if current_transaction
            finalized = finalize_transaction(current_transaction, current_description_lines)
            transactions << finalized if finalized
          end

          # Start new transaction
          current_transaction = parse_transaction_line(line, date_match, amount_match)
          current_description_lines = []
        elsif current_transaction && line.length > 2
          # This is a continuation line (multi-line description)
          current_description_lines << line
        end
      end

      # Don't forget the last transaction
      if current_transaction
        finalized = finalize_transaction(current_transaction, current_description_lines)
        transactions << finalized if finalized
      end

      transactions.compact
    end

    def parse_transaction_line(line, date_match, amount_match)
      # Use the charge date (second date) for the transaction
      charge_day = date_match[3]
      charge_month = date_match[4]

      date = normalize_date(charge_day, charge_month)

      # Extract sign and amount
      # IMPORTANT: Scotiabank uses INVERTED signs
      # + means expense (charge to card)
      # - means income (payment/credit)
      sign = amount_match[1]
      amount_value = amount_match[2].gsub(",", "").to_f

      if sign == "+"
        # This is an expense/charge
        amount = -amount_value
        transaction_type = "variable_expense"
      else
        # This is a payment/credit
        amount = amount_value
        transaction_type = "income"
      end

      # Extract description (between dates and amount)
      description = extract_description(line, date_match, amount_match)

      # Skip if description is too short (validation requires at least 4 chars)
      return if description.blank? || description.length < 4

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

    def extract_description(line, date_match, amount_match)
      # Remove dates (both operation and charge dates)
      desc = line.gsub(DATE_PATTERN, "")

      # Remove amount with sign
      desc = desc.gsub(AMOUNT_PATTERN, "")

      # Remove RFC patterns
      desc = desc.gsub(/[A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3}/, "")

      # Remove USD amounts
      desc = desc.gsub(/[\d.]+\s*USD/, "")

      # Clean up extra whitespace
      desc.gsub(/\s+/, " ").strip
    end

    def finalize_transaction(transaction, continuation_lines)
      return unless transaction

      # Append continuation lines to description
      continuation_lines.each do |line|
        # Clean the continuation line
        cleaned = line.gsub(/[A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3}/, "").strip
        next if cleaned.length < 3

        transaction["description"] += " #{cleaned}"
      end

      transaction["description"] = transaction["description"].gsub(/\s+/, " ").strip

      # Skip if final description is too short
      return if transaction["description"].blank? || transaction["description"].length < 4

      transaction["merchant"] = extract_merchant(transaction["description"])
      transaction
    end

    def extract_reference(line)
      # Look for RFC patterns as reference
      if match = line.match(/([A-Z]{3,4}\s*\d{6}[A-Z0-9]{2,3})/)
        return match[1].gsub(/\s+/, "")
      end

      nil
    end

    def normalize_date(day, month)
      # Determine the year based on statement period
      # If month is Dec (12) and we're processing a Jan statement, use previous year
      month_int = month.to_i

      # Simple heuristic: if month > 6 and statement year looks like it's early in the year,
      # the transaction was from the previous year
      year = @statement_year

      # Check if this might be from the previous year
      # (e.g., December transactions in a January statement)
      if month_int >= 10 && @statement_year
        # Look at the statement - if period ends in Jan/Feb, Dec transactions are from previous year
        year = @statement_year - 1 if month_int == 12
      end

      sprintf("%04d-%02d-%02d", year, month_int, day.to_i)
    end

    def extract_financial_summary(lines)
      summary = {
        "statement_type" => "credit",
        "bank_name" => "Scotiabank"
      }

      opening_balance = nil
      closing_balance = nil
      payment_to_avoid_interest = nil
      minimum_payment = nil
      credit_limit = nil
      available_credit = nil

      lines.each do |line|
        standardized = line.gsub(/\s+/, "").downcase

        # Opening balance (previous period balance)
        if standardized.include?("adeudodelperiodoanterior")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            opening_balance = match[1].gsub(",", "").to_f
          end
        end

        # Closing balance - use "Pago para no generar intereses" as it represents
        # the amount needed to pay to avoid interest (more useful for users)
        if standardized.include?("pagoparanogenerarintereses") && closing_balance.nil?
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            closing_balance = match[1].gsub(",", "").to_f
          end
        end

        # Payment to avoid interest
        if standardized.include?("pagoparanogenerarintereses")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            payment_to_avoid_interest = match[1].gsub(",", "").to_f
          end
        end

        # Minimum payment
        if standardized.include?("pagomínimo") && !standardized.include?("+")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            minimum_payment = match[1].gsub(",", "").to_f
          end
        end

        # Credit limit
        if standardized.include?("límitedecrédito") || standardized.include?("limitedecredito")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            credit_limit = match[1].gsub(",", "").to_f
          end
        end

        # Available credit
        if standardized.include?("créditodisponible") || standardized.include?("creditodisponible")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            available_credit ||= match[1].gsub(",", "").to_f
          end
        end
      end

      summary["opening_balance"] = opening_balance
      summary["closing_balance"] = closing_balance
      summary["payment_to_avoid_interest"] = payment_to_avoid_interest
      summary["minimum_payment"] = minimum_payment
      summary["credit_limit"] = credit_limit
      summary["available_credit"] = available_credit

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: summary
      }
    end
  end
end
