# app/services/pdf_parser/new_bbva_credit_card.rb
module PdfParser
  class NewBbvaCreditCard < Base
    # New format patterns (July 2024+)
    DATE_PATTERN = /(\d{2})-(\w{3})-(\d{4})/  # Handle DD-MMM-YYYY format like "21-jun-2025"
    AMOUNT_PATTERN = /[+\-]\s*\$?\s*([\d,]*\.\d{2})(?:\s{2,}|\s*$|USD|TIPO|TARJETA|DIGITAL)/  # Match amounts that start with + or -, must have decimal part, followed by multiple spaces, end of line, or banking terms

    # New format table headers (July 2024+)
    TABLE_HEADERS = [
      "CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)",
      "COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES",
      "COMPRAS Y CARGOS DIFERIDOS A MESES CON INTERESES"
    ]

    # New format transaction sections (July 2024+)
    TRANSACTION_SECTIONS = [
      "CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)",
      "COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES",
      "COMPRAS Y CARGOS DIFERIDOS A MESES CON INTERESES"
    ]

    def parse(text, context: {})
      lines = text.split("\n")
      transaction_text = extract_transaction_sections(lines)

      # Split the transaction text back into individual lines for parsing
      transaction_lines = transaction_text.split("\n").reject(&:empty?)

      transactions = []
      transaction_lines.each do |line|
        line_transactions = parse_transaction_section([ line ])
        transactions.concat(line_transactions)
      end

      # Apply basic categorization rules as backup
      apply_basic_categorization(transactions)

      {
        "transactions" => transactions,
        "opening_balance" => 0.0, # Default for now
        "closing_balance" => 0.0, # Default for now
        "financial_summaries" => []
      }
    end

    private

    # Apply basic categorization rules for common merchants
    def apply_basic_categorization(transactions)
      transactions.each do |transaction|
        description = transaction["description"].to_s.downcase

        # Food & Restaurants
        if description.match?(/starbucks|mcdonalds|kfc|chilis|tacos|restaurant|food|deli|cafe|bakery/)
          transaction["category"] = "Comida"
          transaction["sub_category"] = "Restaurantes"
        elsif description.match?(/heb|walmart|supercenter|supermercado|market|grocery/)
          transaction["category"] = "Comida"
          transaction["sub_category"] = "Supermercado"
        elsif description.match?(/gas|chevron|arco|shell|pemex|fuel/)
          transaction["category"] = "Transporte"
          transaction["sub_category"] = "Gasolina"
        elsif description.match?(/uber|lyft|taxi|transport|parking|estacionamiento/)
          transaction["category"] = "Transporte"
          transaction["sub_category"] = "Transporte Público"
        elsif description.match?(/home depot|ferreteria|hardware|tools|construction/)
          transaction["category"] = "Compras"
          transaction["sub_category"] = "Hogar"
        elsif description.match?(/amazon|ebay|online|digital|app/)
          transaction["category"] = "Compras"
          transaction["sub_category"] = "Tecnología"
        elsif description.match?(/netflix|spotify|youtube|entertainment|cinema|movie/)
          transaction["category"] = "Entretenimiento"
          transaction["sub_category"] = "Cine"
        elsif description.match?(/gym|fitness|health|medical|doctor|pharmacy/)
          transaction["category"] = "Salud"
          transaction["sub_category"] = "Médico"
        elsif description.match?(/cfed|electric|water|internet|phone|telecom/)
          transaction["category"] = "Servicios"
          transaction["sub_category"] = "Luz"
        elsif description.match?(/payment|pago|credit|refund|abono/)
          transaction["category"] = "Ingresos"
          transaction["sub_category"] = "Otros Ingresos"
        else
          # Default categorization
          transaction["category"] = "Sin Categorizar"
          transaction["sub_category"] = nil
        end

        # Set confidence scores for basic categorization
        transaction["category_confidence"] = 0.7
        transaction["transaction_type_confidence"] = 0.9
      end
    end

    def extract_transaction_sections(lines)
      transaction_lines = []

      # Since the text filtering removes section headers, look for transaction patterns directly
      lines.each do |line|
        # Look for lines that contain transaction patterns
        if line.match?(DATE_PATTERN) && line.match?(AMOUNT_PATTERN)
          transaction_lines << line
        end
      end

      transaction_lines.join("\n")
    end

    def extract_financial_summary_sections(lines)
      summary_lines = []
      in_summary_section = false

      lines.each do |line|
        # Start of financial summary section
        if line.include?("RESUMEN DE CARGOS Y ABONOS DEL PERIODO") ||
           line.include?("DISTRIBUCIÓN DE TU ÚLTIMO PAGO") ||
           line.include?("TOTAL CARGOS") ||
           line.include?("TOTAL ABONOS")
          in_summary_section = true
          summary_lines << line
          next
        end

        # End of financial summary section
        if in_summary_section && line.match?(/^NOTAS ACLARATORIAS|^BBVA/)
          break
        end

        # Collect summary section lines
        if in_summary_section
          summary_lines << line
        end
      end

      summary_lines.join("\n")
    end

    def combine_sections_for_ai(transaction_text, financial_summary_text)
      <<~TEXT
        BBVA Credit Card Statement - New Format (July 2024+) - Transactions and Financial Summaries

        === TRANSACTIONS ===
        #{transaction_text}

        === FINANCIAL SUMMARIES ===
        #{financial_summary_text}

        IMPORTANT: This statement uses the new BBVA format (July 2024+) where:
        - Expenses/charges appear as POSITIVE amounts (+$193.20, +$444.52, etc.)
        - Payments/credits appear as NEGATIVE amounts (-$54,538.87)

        In our system, we need to INVERT these signs:
        - Expenses should be NEGATIVE (variable_expense, debit)
        - Payments should be POSITIVE (income, credit)

        Please parse the above BBVA credit card statement and extract:
        1. All transactions with dates, descriptions, amounts, and types
        2. Financial summaries including opening/closing balances, totals, fees, and installment information

        Return the data in JSON format with transactions and financial_summaries arrays.
      TEXT
    end

    def parse_with_ai(text, context)
      # Create a simple prompt for new BBVA parsing
      prompt = build_prompt(text)

      begin
        # For now, let's just return nil to test the fallback
        # In production, this would call the AI service
        nil
      rescue => e
        Rails.logger.warn("AI parsing failed: #{e.message}")
        nil
      end
    end

    def build_prompt(text)
      <<~PROMPT
        Parse the following BBVA credit card statement text into JSON format.

        IMPORTANT: This statement uses the new BBVA format (July 2024+) where:
        - Expenses/charges appear as POSITIVE amounts (+$193.20, +$444.52, etc.)
        - Payments/credits appear as NEGATIVE amounts (-$54,538.87)

        In our system, we need to INVERT these signs:
        - Expenses should be NEGATIVE (variable_expense, debit)
        - Payments should be POSITIVE (income, credit)

        Extract:
        1. All transactions with dates, descriptions, amounts, and types
        2. Financial summaries including balances, fees, and totals

        For transactions, use:
        - transaction_type: "income" for payments/credits, "variable_expense" for charges/expenses
        - bank_entry_type: "credit" for payments/credits, "debit" for charges/expenses
        - amount: negative for expenses, positive for income (remember to invert the signs from the statement)

        For financial summaries, use:
        - type: "balance", "fee", "interest", "commission", "installment", "total", or "other"

        Return JSON with transactions and financial_summaries arrays.

        Statement text:
        #{text}
      PROMPT
    end

    def parse_deterministic(lines)
      transactions = []

      # Find and parse all transaction sections
      transaction_sections = find_transaction_sections(lines)

      transaction_sections.each do |section|
        section_transactions = parse_transaction_section(section)
        transactions.concat(section_transactions)
      end

      # Remove duplicates and sort by date
      transactions = deduplicate_transactions(transactions)
      transactions.sort_by! { |t| Date.parse(t["date"]) }

      {
        "opening_balance" => extract_balance_from_lines(lines, "opening"),
        "closing_balance" => extract_balance_from_lines(lines, "closing"),
        "transactions" => transactions,
        "extraction_source" => "ai_enhanced_parser"
      }
    end

    def find_transaction_sections(lines)
      sections = []
      current_section = []

      # Since the text filtering removes section headers, look for transaction patterns directly
      lines.each do |line|
        # If this line looks like a transaction, start a new section
        if line.match?(DATE_PATTERN) && line.match?(AMOUNT_PATTERN)
          if current_section.any?
            sections << current_section
          end
          current_section = [ line ]
        elsif current_section.any?
          # This is a continuation line (like USD conversion info)
          current_section << line
        end
      end

      # Add the last section if it exists
      if current_section.any?
        sections << current_section
      end

      sections
    end

    def parse_transaction_section(section_lines)
      transactions = []

      # Look for table structure with proper headers
      if has_table_structure?(section_lines)
        transactions = parse_table_structure(section_lines)
      else
        transactions = parse_free_form_transactions(section_lines)
      end

      transactions
    end

    def has_table_structure?(lines)
      # Check if we have the new BBVA table headers
      has_headers = lines.any? do |line|
        TABLE_HEADERS.any? do |header|
          line.include?(header)
        end
      end

      # Check if we have multiple transaction-like lines with the new date format
      has_transaction_lines = lines.count do |line|
        line.match?(DATE_PATTERN) && line.match?(AMOUNT_PATTERN)
      end >= 3  # At least 3 transaction-like lines



      has_headers || has_transaction_lines
    end

    def parse_table_structure(lines)
      transactions = []

      # Find the header line to understand column positions
      header_line = lines.find { |line| TABLE_HEADERS.any? { |header| line.include?(header) } }

      # Parse each line that looks like a transaction
      lines.each do |line|
        if line == header_line
          next
        end

        if line.match?(/^TOTAL|^Notas:|^BBVA/)
          next
        end

        transaction = parse_table_line(line)
        if transaction
          transactions << transaction
        end
      end

      transactions
    end

    def parse_table_line(line)
      # Handle the new format with columns: Fecha operación, Fecha cargo, Descripción, Monto
      # Look for the new date pattern first (handle both single and double date formats)
      date_matches = line.scan(DATE_PATTERN)
      return nil if date_matches.empty?

      # Use the first date for the transaction date
      day, month, year = date_matches[0]

      # Look for amounts in the line using a smarter approach
      # First, try to find amounts at the end of the line or before banking terms
      amount_match = extract_amount_smart(line)
      return nil unless amount_match

      # Extract date components (already extracted above)
      # day, month, year are already set from date_matches[0]

      # Extract amount and determine transaction type
      amount_str = amount_match[:amount]
      raw_amount = amount_str.gsub(",", "").to_f
      original_sign = amount_match[:sign]

      # Check if the amount has a sign in the original text

      if original_sign
        # Amount has explicit sign in statement
        if original_sign.start_with?("+")
          # This is an expense (positive in statement, should be negative in our system)
          amount = -raw_amount
          transaction_type = "variable_expense"
          bank_entry_type = "debit"
        else
          # This is a payment (negative in statement, should be positive in our system)
          amount = raw_amount.abs
          transaction_type = "income"
          bank_entry_type = "credit"
        end
      else
        # No explicit sign, determine from context
        if line.downcase.include?("pago") || line.downcase.include?("abono")
          # This is a payment
          amount = raw_amount.abs
          transaction_type = "income"
          bank_entry_type = "credit"
        else
          # This is an expense
          amount = -raw_amount
          transaction_type = "variable_expense"
          bank_entry_type = "debit"
        end
      end

      # Extract description (remove date and amount, clean up)
      description = extract_description(line, amount_match, amount_match)

      # Extract additional info
      reference = extract_reference(line)
      merchant = extract_merchant(description)

      {
        "date" => normalize_date(day, month, year),
        "description" => description.strip,
        "amount" => sprintf("%.2f", amount),
        "transaction_type" => transaction_type,
        "bank_entry_type" => bank_entry_type,
        "merchant" => merchant,
        "reference" => reference,
        "category" => "Sin Categorizar",
        "sub_category" => nil,
        "raw_text" => line,
        "confidence" => 0.95,
        "category_confidence" => 0.8,
        "transaction_type_confidence" => 0.98
      }
    end

    def parse_free_form_transactions(lines)
      transactions = []

      lines.each do |line|
        next if line.match?(/^TOTAL|^Notas:|^BBVA/)

        # Look for lines with new date and amount patterns
        date_match = line.match(DATE_PATTERN)
        next unless date_match

        # Look for amounts in the line using the smart approach
        amount_match = extract_amount_smart(line)
        next unless amount_match

        # Extract description
        description = extract_description(line, amount_match, amount_match)

        # Extract amount and determine transaction type
        amount_str = amount_match[:amount]
        raw_amount = amount_str.gsub(",", "").to_f
        original_sign = amount_match[:sign]

        if original_sign
          # Amount has explicit sign in statement
          if original_sign[0].start_with?("+")
            # This is an expense (positive in statement, should be negative in our system)
            amount = -raw_amount
            transaction_type = "variable_expense"
            bank_entry_type = "debit"
          else
            # This is a payment (negative in statement, should be positive in our system)
            amount = raw_amount.abs
            transaction_type = "income"
            bank_entry_type = "credit"
          end
        else
          # No explicit sign, determine from context
          if line.downcase.include?("pago") || line.downcase.include?("abono")
            # This is a payment
            amount = raw_amount.abs
            transaction_type = "income"
            bank_entry_type = "credit"
          else
            # This is an expense
            amount = -raw_amount
            transaction_type = "variable_expense"
            bank_entry_type = "debit"
          end
        end

        # Extract additional info
        reference = extract_reference(line)
        merchant = extract_merchant(description)

        transactions << {
          "date" => normalize_date(date_match[1], date_match[2], date_match[3]),
          "description" => description.strip,
          "amount" => sprintf("%.2f", amount),
          "transaction_type" => transaction_type,
          "bank_entry_type" => bank_entry_type,
          "merchant" => merchant,
          "reference" => reference,
          "category" => "Sin Categorizar",
          "sub_category" => nil,
          "raw_text" => line,
          "confidence" => 0.9,
          "category_confidence" => 0.7,
          "transaction_type_confidence" => 0.95
        }
      end

      transactions
    end

    def extract_amount_smart(line)
      # Look for amounts at the end of the line or before banking terms
      # This method is smarter about finding actual monetary amounts vs dates

      # First, try to find amounts at the end of the line
      end_amount_match = line.match(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})\s*$/)
      if end_amount_match
        # Get the sign that's actually associated with this amount
        sign = end_amount_match[0].match(/[+\-]/)[0]
        return { amount: end_amount_match[1], sign: sign }
      end

      # Look for amounts followed by banking terms (USD, TIPO, etc.)
      banking_amount_match = line.match(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})\s+(USD|TIPO|TARJETA|DIGITAL|DE|CUENTA|CREDITO)/)
      if banking_amount_match
        # Get the sign that's actually associated with this amount
        sign = banking_amount_match[0].match(/[+\-]/)[0]
        return { amount: banking_amount_match[1], sign: sign }
      end

      # Look for amounts followed by multiple spaces (indicating end of transaction)
      space_amount_match = line.match(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})\s{2,}/)
      if space_amount_match
        # Get the sign that's actually associated with this amount
        sign = space_amount_match[0].match(/[+\-]/)[0]
        return { amount: space_amount_match[1], sign: sign }
      end

      # If no specific pattern found, look for the last amount in the line
      # that's not part of a date
      all_amounts = line.scan(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})/)
      if all_amounts.any?
        # Find the last amount that's not part of a date pattern
        line_parts = line.split(/\s+/)
        line_parts.reverse.each do |part|
          amount_match = part.match(/[+\-]\s*\$?\s*([\d,]*\.?\d{2})/)
          if amount_match && !part.match?(/\d{2}-\w{3}-\d{4}/)
            sign = part.match(/[+\-]/)[0]
            return { amount: amount_match[1], sign: sign }
          end
        end
      end

      nil
    end

    def extract_description(line, date_match, amount_match)
      # Remove the date from the line (handle both date columns)
      line_without_date = line.gsub(/\d{2}-\w{3}-\d{4}/, "")

      # Remove amount patterns - amount_match is now a hash with :amount and :sign keys
      if amount_match && amount_match.is_a?(Hash) && amount_match[:amount]
        # Remove the specific amount that was found
        amount_pattern = /[+\-]\s*\$?\s*#{Regexp.escape(amount_match[:amount])}/
        line_without_amounts = line_without_date.gsub(amount_pattern, "")

        # Also try to remove the original corrupted format if it exists
        # This handles cases where the amount was extracted as "0.99" from "+ .99"
        if amount_match[:amount].start_with?("0") && amount_match[:amount].length > 1
          # Remove the corrupted format like "+ .99" or "- .20"
          corrupted_pattern = /[+\-]\s*\.#{amount_match[:amount][1..-1]}/
          line_without_amounts = line_without_amounts.gsub(corrupted_pattern, "")
        end
      else
        # Fallback to old pattern if needed
        line_without_amounts = line_without_date.gsub(AMOUNT_PATTERN, "")
      end

      # Remove common banking terms that shouldn't be in description
      line_cleaned = line_without_amounts
        .gsub(/USD\s+\$\d+\.\d+\s+TIPO DE CAMBIO\s+\$\d+\.\d+/, "")  # Remove USD conversion info
        .gsub(/USD\s+\$\d+\.\d+\s+TIPO DE CAMBIO\s+\$\d+\.\d+/, "")  # Remove USD conversion info (alternative format)
        .gsub(/USD\s+[$\d]*\.?\d*\s+TIPO DE CAMBIO\s+[$\d]*\.?\d*/, "")  # Remove corrupted USD conversion info
        .gsub(/USDTIPO DE CAMBIO/, "")  # Remove any remaining USD conversion text
        .gsub(/Tarjeta Digital \*{3,}\d+/, "")  # Remove card info
        .gsub(/\d+\s+de\s+\d+\s+\d+\.\d+%/, "")  # Remove installment info like "3 de 12 0.00%"
        .gsub(/;\s*$/, "")  # Remove trailing semicolons
        .gsub(/[+\-]\s*\.\d+/, "")  # Remove any remaining corrupted amounts like "+ .99" or "- .20"
        .gsub(/\s+/, " ")    # Normalize whitespace
        .strip

      # Take only the first meaningful part (before any extra banking info)
      parts = line_cleaned.split(/\s{2,}/)
      parts.first || line_cleaned
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

    def extract_merchant(description)
      # Handle specific merchant cases first
      description_lower = description.downcase

      if description_lower.include?("starbucks")
        return "STARBUCKS"
      elsif description_lower.include?("amazon")
        return "AMAZON"
      elsif description_lower.include?("netflix")
        return "NETFLIX"
      elsif description_lower.include?("tesla")
        return "TESLA"
      elsif description_lower.include?("home depot")
        return "HOME DEPOT"
      elsif description_lower.include?("ticketmaster")
        return "TICKETMASTER"
      elsif description_lower.include?("ross")
        return "ROSS STORES"
      elsif description_lower.include?("heb")
        return "HEB"
      elsif description_lower.include?("kfc")
        return "KFC"
      elsif description_lower.include?("arco")
        return "ARCO"
      elsif description_lower.include?("walmart") || description_lower.include?("wm supercenter")
        return "WALMART"
      end

      # For now, just return the description as the merchant
      description
    end

    def normalize_date(day, month, year)
      # Convert DD-MMM-YYYY to YYYY-MM-DD
      month_map = {
        "ene" => "01", "feb" => "02", "mar" => "03", "abr" => "04",
        "may" => "05", "jun" => "06", "jul" => "07", "ago" => "08",
        "sep" => "09", "oct" => "10", "nov" => "11", "dic" => "12"
      }

      month_num = month_map[month.downcase]
      return nil unless month_num

      "#{year}-#{month_num}-#{day}"
    end

    def extract_balance_from_lines(lines, balance_type)
      # Extract balance from new format
      lines.each do |line|
        if balance_type == "opening" && line.include?("Adeudo del periodo anterior")
          # Extract opening balance
          if match = line.match(/(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        elsif balance_type == "closing" && line.include?("Saldo deudor total")
          # Extract closing balance
          if match = line.match(/(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        end
      end
      nil
    end

    def deduplicate_transactions(transactions)
      # Group by date, description, and absolute amount to find duplicates
      grouped = transactions.group_by { |t| [ t["date"], t["description"], t["amount"].to_f.abs ] }

      # Take only the first occurrence of each unique transaction
      grouped.values.map(&:first)
    end
  end
end
