# app/services/pdf_parser/new_bbva_credit_card.rb
module PdfParser
  class NewBbvaCreditCard < Base
    include MerchantExtraction
    # New format patterns (July 2024+)
    DATE_PATTERN = /(\d{2})-(\w{3})-(\d{4})/  # Handle DD-MMM-YYYY format like "21-jun-2025"

    # New format transaction sections (July 2024+)
    TRANSACTION_SECTIONS = [
      "CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)",
      "COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES",
      "COMPRAS Y CARGOS DIFERIDOS A MESES CON INTERESES"
    ]

    # Regex patterns for section detection
    REGULAR_SECTION_PATTERN = /CARGOS,?\s*COMPRAS\s+Y\s+ABONOS\s+REGULARES\s*\(NO\s*A\s*MESES\)/i
    DEFERRED_SECTION_PATTERNS = [
      /COMPRAS\s+Y\s+CARGOS\s+DIFERIDOS\s+A\s+MESES\s+SIN\s+INTERESES/i,
      /COMPRAS\s+Y\s+CARGOS\s+DIFERIDOS\s+A\s+MESES\s+CON\s+INTERESES/i
    ]
    SUMMARY_SECTION_INDICATORS = [
      /^TOTAL CARGOS\s+.*\$/,  # Line starts with "TOTAL CARGOS" followed by amount
      /^TOTAL ABONOS\s+.*\$/,  # Line starts with "TOTAL ABONOS" followed by amount
      /^TOTAL CARGOS\s+[\d,]+\.\d{2}$/,  # Line starts with "TOTAL CARGOS" followed by amount
      /^TOTAL ABONOS\s+[\d,]+\.\d{2}$/   # Line starts with "TOTAL ABONOS" followed by amount
    ]

    # Amount extraction patterns in order of preference
    AMOUNT_PATTERNS = [
      /[+\-]\s*\$([\d,]*\.?\d{2})/,  # Pattern 1: Dollar sign format (+ $767.00) - MOST SPECIFIC
      /[+\-]\s*\$?\s*([\d,]*\.?\d{2})\s*$/,  # Pattern 2: End of line (+ 767.00$) - SPECIFIC
      /[+\-]\s*\$?\s*([\d,]*\.?\d{2})\s+(USD|TIPO|TARJETA|DIGITAL|DE|CUENTA|CREDITO)/,  # Pattern 3: Banking terms (+ 767.00 USD) - SPECIFIC
      /[+\-]\s*\.(\d{2})\s+(USD|TIPO|TARJETA|DIGITAL|DE|CUENTA|CREDITO)/,  # Pattern 4: Decimal amounts (+ .20 USD) - SPECIFIC
      /[+\-]\s*\.(\d{2})\s+USD\s+\.(\d{2})\s+TIPO DE CAMBIO\s+\.(\d{2})/  # Pattern 5: USD conversion (+ .20 USD .07 TIPO DE CAMBIO .19) - SPECIFIC
    ]

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Extract only from the regular transaction section to avoid duplicates
      # Skip "COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES" section
      # as these transactions are already included in the regular section
      transaction_sections = find_transaction_sections(lines)

      transactions = []
      transaction_sections.each do |section|
        section_transactions = parse_transaction_section(section)
        transactions.concat(section_transactions)
      end

      # Remove duplicates based on date, description, and amount
      transactions = deduplicate_transactions(transactions)

      # Extract structured financial summary
      financial_summary_text = extract_financial_summary_sections(lines)
      financial_summary = extract_financial_summary(financial_summary_text)

      {
        "extraction_source" => "deterministic_parser",
        "transactions" => transactions,
        "opening_balance" => financial_summary&.dig("opening_balance"),
        "closing_balance" => financial_summary&.dig("closing_balance"),
        "financial_summaries" => financial_summary ? [ financial_summary ] : []
      }
    end

    private

    def extract_financial_summary_sections(lines)
      summary_lines = []
      in_summary_section = false

      lines.each do |line|
        # Start of financial summary section - only the structured summary boxes
        if line.include?("RESUMEN DE CARGOS Y ABONOS DEL PERIODO") ||
           line.include?("INDICADORES DEL COSTO ANUAL TOTAL DE LA TARJETA") ||
           line.include?("NIVEL DE USO DE TU TARJETA") ||
           line.include?("MENSAJES IMPORTANTES")
          in_summary_section = true
          summary_lines << line
          next
        end

        # End of financial summary section
        if in_summary_section && (line.match?(/^NOTAS ACLARATORIAS|^BBVA/) ||
                                 line.include?("CARGOS,COMPRAS Y ABONOS REGULARES") ||
                                 line.include?("COMPRAS Y CARGOS DIFERIDOS"))
          break
        end

        # Collect summary section lines
        if in_summary_section
          summary_lines << line
        end
      end

      summary_lines.join("\n")
    end

    def find_transaction_sections(lines)
      sections = []
      current_section = []
      in_regular_section = false
      in_deferred_section = false

      lines.each do |line|
        # Start of regular transaction section (this is what we want)
        if line.match?(REGULAR_SECTION_PATTERN)
          # Only process the first regular section to avoid duplicates
          if in_regular_section
            # Skip subsequent regular sections
            next
          end

          # Start collecting the first regular section
          current_section = [ line ]
          in_regular_section = true
          in_deferred_section = false
          next
        end

        # Skip deferred charges sections to avoid duplicates
        if DEFERRED_SECTION_PATTERNS.any? { |pattern| line.match?(pattern) }
          in_deferred_section = true
          in_regular_section = false
          next
        end

        # End sections when we hit summary sections
        if SUMMARY_SECTION_INDICATORS.any? { |pattern| line.match?(pattern) }
          if in_regular_section
            sections << current_section
          end
          break
        end

        # Skip lines while in deferred section
        next if in_deferred_section

        # Collect lines from the regular section
        if in_regular_section
          current_section << line
        end
      end

      # Add the current section if we're still in a regular section
      if in_regular_section
        sections << current_section
      end

      sections
    end

    def parse_transaction_section(lines)
      transactions = []

      lines.each do |line|
        next if line.match?(/^TOTAL|^Notas:|^BBVA/)

        # Look for lines with new date and amount patterns
        date_match = line.match(DATE_PATTERN)
        next unless date_match

        # Look for amounts in the line using the smart approach
        amount_match = extract_amount_smart(line)
        next unless amount_match

        description = extract_description(line, date_match, amount_match)
        amount_data = determine_transaction_type(amount_match, line)
        reference = extract_reference(line)
        merchant = extract_merchant(description)

        transaction = {
          "date" => normalize_date(date_match[1], date_match[2], date_match[3]),
          "description" => description.strip,
          "amount" => sprintf("%.2f", amount_data[:amount]),
          "transaction_type" => amount_data[:transaction_type],
          "merchant" => merchant,
          "reference" => reference,
          "raw_text" => line
        }
        transactions << transaction
      end

      transactions
    end

    def determine_transaction_type(amount_str, line)
      # amount_str now includes the sign (e.g., "+193.20" or "-193.20")
      raw_amount = amount_str.gsub(",", "").to_f

      if amount_str.start_with?("+")
        # This is a purchase/expense (positive in statement, should be negative in our system)
        amount = -raw_amount
        transaction_type = "variable_expense"
      elsif amount_str.start_with?("-")
        # This is a payment/credit (negative in statement, should be positive in our system)
        amount = raw_amount.abs
        transaction_type = "income"
      end

      { amount: amount, transaction_type: transaction_type }
    end

    def extract_amount_smart(line)
      # Try each pattern in order
      AMOUNT_PATTERNS.each do |pattern|
        match = line.match(pattern)
        next unless match

        # Handle decimal amounts (patterns 5 & 6)
        if pattern.to_s.include?('\\.(\\d{2})')
          amount = "0.#{match[1]}"
        else
          amount = match[1]
        end

        # Find the sign for this amount - look for the sign that's actually associated with this amount
        # We need to find the sign that appears right before the amount we extracted
        amount_pattern = /[+\-]\s*\$?#{Regexp.escape(amount)}/
        amount_with_sign = line.match(amount_pattern)
        if amount_with_sign
          sign = amount_with_sign[0].match(/[+\-]/)[0]
          return "#{sign}#{amount}"
        else
          # Fallback: find any sign in the line (this might be wrong)
          sign = line.match(/[+\-]/)[0]
          return "#{sign}#{amount}"
        end
      end

      # Fallback: Find last amount that's not a date
      fallback_match = line.scan(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})/).last
      if fallback_match && !line.match?(/\d{2}-\w{3}-\d{4}/)
        sign = line.match(/[+\-]/)[0]
        return "#{sign}#{fallback_match[0]}"
      end

      nil
    end

    def extract_description(line, date_match, amount_match)
      # Remove the date from the line (handle both date columns)
      line_without_date = line.gsub(/\d{2}-\w{3}-\d{4}/, "")

      # Remove amount patterns - use the original patterns to remove amounts
      line_without_amounts = line_without_date
      AMOUNT_PATTERNS.each do |pattern|
        line_without_amounts = line_without_amounts.gsub(pattern, "")
      end

      # Only remove basic formatting issues, preserve transaction details
      line_cleaned = line_without_amounts
        .gsub(/USD\s+\$?\d*\.?\d+\s+TIPO DE CAMBIO\s+\$?\d*\.?\d+/, "")  # Remove USD conversion info
        .gsub(/USDTIPO DE CAMBIO/, "")  # Remove any remaining USD conversion text
        .gsub(/\.\d{2}\s+TIPO DE CAMBIO\s+\.\d{2}/, "")  # Remove remaining USD conversion text (e.g., ".07 TIPO DE CAMBIO .19")
        .gsub(/;\s*Tarjeta Digital \*{3,}\d{4}/, "")  # Remove card information
        .gsub(/;\s*$/, "")  # Remove trailing semicolons
        .gsub(/\s+/, " ")    # Normalize whitespace
        .strip

      line_cleaned
    end

    def extract_reference(line)
      # Look for reference patterns in order of preference
      reference_patterns = [
        /\b(\d{9,})\b/,  # 9+ digit numbers
        /\b([A-Z]{2,}\d{3,})\b/,  # Letters + numbers
        /\b(\*{3,}\d{4})\b/,  # Masked card numbers (like ***2064)
        /\b(\d{6,})\b/  # 6+ digit numbers
      ]

      reference_patterns.each do |pattern|
        match = line.match(pattern)
        if match
          reference = match[1]
          # Skip if it's clearly a date or amount
          next if reference.match?(/^\d{2}$/) || reference.match?(/^\d{4}$/)

          return reference
        end
      end

      nil
    end

    def normalize_date(day, month, year)
      # Convert DD-MMM-YYYY to YYYY-MM-DD
      month_map = {
        "ene" => "01", "feb" => "02", "mar" => "03", "abr" => "04",
        "may" => "05", "jun" => "06", "jul" => "07", "ago" => "08",
        "sep" => "09", "oct" => "10", "nov" => "11", "dic" => "12"
      }

      month_num = month_map[month.downcase]
      return unless month_num

      "#{year}-#{month_num}-#{day}"
    end

    def extract_financial_summary(financial_summary_text)
      return if financial_summary_text.blank?

      lines = financial_summary_text.split("\n")

      summary = {
        "statement_type" => "credit",
        "bank_name" => "BBVA"
      }

      # Extract opening and closing balances
      opening_balance = extract_balance_from_lines(lines, "opening")
      closing_balance = extract_balance_from_lines(lines, "closing")

      summary["opening_balance"] = opening_balance if opening_balance
      summary["closing_balance"] = closing_balance if closing_balance

      # Initialize variables for credit card specific data
      total_charges = 0.0
      total_payments = 0.0
      interest_charged = 0.0
      credit_limit = nil
      available_credit = nil
      payment_to_avoid_interest = nil

      # Extract additional financial information
      lines.each do |line|
        standardized_line = line.gsub(/\s+/, "")  # Remove all spaces for consistent matching

        # Extract regular charges
        if standardized_line.include?("Cargosregulares") && match = line.match(/\+?\$?(\d{1,3}(?:,\d{3})*\.?\d*)/)
          total_charges += match[1].gsub(",", "").to_f
        end

        # Extract monthly installment charges
        if standardized_line.include?("Cargoscomprasameses") && match = line.match(/\+?\$?(\d{1,3}(?:,\d{3})*\.?\d*)/)
          total_charges += match[1].gsub(",", "").to_f
        end

        # Extract interest amount
        if standardized_line.include?("Montodeintereses") && match = line.match(/\+?\$?(\d{1,3}(?:,\d{3})*\.?\d*)/)
          interest_charged = match[1].gsub(",", "").to_f
        end

        # Extract payments and credits (these are negative in the statement)
        if standardized_line.include?("Pagos") && match = line.match(/-?\s*\$?(\d{1,3}(?:,\d{3})*\.?\d*)/)
          total_payments = match[1].gsub(",", "").to_f
        end

        # Extract payment to avoid interest
        if standardized_line.include?("PAGOPARANOGENERARINTERESES") && match = line.match(/\$(\d{1,3}(?:,\d{3})*\.?\d*)/)
          payment_to_avoid_interest = match[1].gsub(",", "").to_f
        end

        # Extract credit limit
        if standardized_line.include?("Límitedecrédito") && match = line.match(/\$(\d{1,3}(?:,\d{3})*\.?\d*)/)
          credit_limit = match[1].gsub(",", "").to_f
        end

        # Extract available credit
        if standardized_line.include?("Créditodisponible") && match = line.match(/\$(\d{1,3}(?:,\d{3})*\.?\d*)/)
          available_credit = match[1].gsub(",", "").to_f
        end
      end

      # Add credit card specific data in the format expected by FinancialSummaryService
      summary["total_charges"] = total_charges
      summary["total_payments"] = total_payments
      summary["interest_charged"] = interest_charged
      summary["credit_limit"] = credit_limit
      summary["available_credit"] = available_credit
      summary["payment_to_avoid_interest"] = payment_to_avoid_interest

      summary
    end

    def extract_balance_from_lines(lines, balance_type)
      # Extract balance from new format - standardize text by removing spaces
      lines.each do |line|
        standardized_line = line.gsub(/\s+/, "")  # Remove all spaces

        if balance_type == "opening" && standardized_line.include?("Adeudodelperiodoanterior")
          # Extract opening balance - look for $XX,XXX.XX pattern
          if match = line.match(/\$(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        elsif balance_type == "closing" && standardized_line.include?("Saldodeudortotal")
          # Extract closing balance - look for $XX,XXX.XX pattern after "Saldo deudor total"
          if match = line.match(/Saldo deudor total.*?\$(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        end
      end
      nil
    end

    def deduplicate_transactions(transactions)
      # Remove duplicates based on date, description, and amount
      seen = Set.new
      unique_transactions = []

      transactions.each do |transaction|
        # Create a key based on date, description, and amount
        key = "#{transaction["date"]}_#{transaction["description"]}_#{transaction["amount"]}"

        unless seen.include?(key)
          seen.add(key)
          unique_transactions << transaction
        end
      end

      unique_transactions
    end
  end
end
