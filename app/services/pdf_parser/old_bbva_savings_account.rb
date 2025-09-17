# app/services/pdf_parser/old_bbva_savings_account.rb
module PdfParser
  class OldBbvaSavingsAccount < Base
    include Concerns::CommonParsingPatterns
    include Concerns::TextProcessing
    include Concerns::DateParsing
    include Concerns::FinancialSummaryExtraction
    include Concerns::TransactionClassification
    include Concerns::TransactionParsing

    def extraction_source
      "bbva_savings_parser"
    end

    private

    def extract_financial_summary(lines)
      # Use the shared concern but add BBVA-specific logic
      summary = extract_financial_summary_base(lines, "BBVA")

      # Look for financial summary section
      financial_section_start = lines.find_index { |line| line.include?("Información Financiera") }
      return summary unless financial_section_start

      # Extract additional BBVA-specific information
      lines.each_with_index do |line, index|
        next if index < financial_section_start

        # Look for interest earned
        if line.include?("Intereses a Favor")
          amount = extract_amount_from_line(line)
          summary["interest_earned"] = amount if amount
        end

        # Look for average balance
        if line.match(/^Saldo Promedio:\s*[\d,]+\.\d{2}/)
          amount = extract_amount_from_line(line)
          summary["average_balance"] = amount if amount
        end

        # Look for period dates
        if line.include?("Días del Periodo")
          days = extract_number_from_line(line)
          summary["period_days"] = days if days
        end

        # Stop if we reach the end of financial section
        break if line.include?("Comisiones") && line.include?("Total Comisiones")
      end

      summary
    end

    def extract_transactions(lines)
      transactions = []

      # Look for transaction table headers
      transaction_start = lines.find_index { |line| line.include?("Detalle de Movimientos Realizados") }
      return [] unless transaction_start

      # Find the actual table start (after headers)
      table_start = find_transaction_table_start(lines, transaction_start)
      return [] unless table_start

      # Parse transactions
      current_transaction = nil

      lines[table_start..-1].each do |line|
        # Skip if we reach the end of transactions
        break if line.include?("Total de Movimientos") || line.include?("Estado de cuenta de Apartados")

        # Check if this line contains a transaction
        if is_transaction_line?(line)
          # Save previous transaction if exists
          transactions << current_transaction if current_transaction

          # Start new transaction
          current_transaction = parse_transaction_line(line)
        elsif current_transaction && line.strip.present?
          # This might be additional description or reference info
          current_transaction = enhance_transaction_with_additional_info(current_transaction, line)
        end
      end

      # Don't forget the last transaction
      transactions << current_transaction if current_transaction

      transactions
    end

            def find_transaction_table_start(lines, start_index)
      # Look for the table headers (FECHA, OPER, LIQ, DESCRIPCIÓN, etc.)
      # BBVA statement has headers split across multiple lines
      (start_index..lines.length - 1).each do |index|
        line = lines[index]

        # Check if this line contains the key header elements
        if line.include?("FECHA") && (line.include?("CARGOS") || line.include?("ABONOS"))
          return index + 1  # Return the line after headers
        end
        # Also check for the specific BBVA header pattern
        if line.include?("OPER") && line.include?("LIQ") && line.include?("DESCRIPCIÓN")
          return index + 1  # Return the line after headers
        end
        # Check for the specific BBVA header pattern that spans multiple lines
        if line.include?("FECHA") && line.include?("SALDO")
          # Look for the next line that contains OPER, LIQ, DESCRIPCIÓN
          (index + 1..[ index + 5, lines.length - 1 ].min).each do |next_index|
            next_line = lines[next_index]
            if next_line.include?("OPER") && next_line.include?("LIQ") && next_line.include?("DESCRIPCIÓN")
              # Look for the line after the complete headers
              # The headers might be split across multiple lines, so look for the line after
              # we see both CARGOS and ABONOS
              (next_index + 1..[ next_index + 3, lines.length - 1 ].min).each do |header_end_index|
                header_end_line = lines[header_end_index]
                if header_end_line.include?("CARGOS") || header_end_line.include?("ABONOS") || header_end_line.include?("LIQUIDACIÓN") || header_end_line.include?("ACIÓN")
                  # This is still part of the header, continue
                  next
                else
                  # This should be the first transaction line
                  return header_end_index
                end
              end
              # If we get here, return the line after the last header line
              return next_index + 2
            end
          end
        elsif line.include?("FECHA") && !line.include?("SALDO")
          # FECHA is on its own line, look for SALDO on the next line
          if index + 1 < lines.length && lines[index + 1].include?("SALDO")
            # Now look for the line that contains OPER, LIQ, DESCRIPCIÓN
            (index + 2..[ index + 6, lines.length - 1 ].min).each do |next_index|
              next_line = lines[next_index]
              if next_line.include?("OPER") && next_line.include?("LIQ") && next_line.include?("DESCRIPCIÓN")
                # Look for the line after the complete headers
                # The headers might be split across multiple lines, so look for the line after
                # we see both CARGOS and ABONOS
                (next_index + 1..[ next_index + 3, lines.length - 1 ].min).each do |header_end_index|
                  header_end_line = lines[header_end_index]
                  if header_end_line.include?("CARGOS") || header_end_line.include?("ABONOS") || header_end_line.include?("LIQUIDACIÓN") || header_end_line.include?("ACIÓN")
                    # This is still part of the header, continue
                    next
                  else
                    # This should be the first transaction line
                    return header_end_index
                  end
                end
                # If we get here, return the line after the last header line
                return next_index + 2
              end
            end
          end
        end
      end
      nil
    end

    def is_transaction_line?(line)
      # Check if line contains date pattern and amount
      date_pattern = /\d{2}\/[A-Z]{3}/
      amount_pattern = /[\d,]+\.\d{2}/

      # Must have a date and amount, and not be a header line
      has_date = line.match?(date_pattern)
      has_amount = line.match?(amount_pattern)
      is_header = line.include?("FECHA") || line.include?("OPER") || line.include?("LIQ") || line.include?("DESCRIPCIÓN") || line.include?("REFERENCIA") || line.include?("CARGOS") || line.include?("ABONOS")

      has_date && has_amount && !is_header
    end

    def parse_transaction_line(line)
      # For BBVA savings account format, we need to parse the line more carefully
      # Format: FECHA OPER LIQ DESCRIPCIÓN REFERENCIA CARGOS ABONOS SALDO_OPERACIÓN SALDO_LIQUIDACIÓN
      # This parser handles both actual BBVA statement format and test data format

      transaction = create_base_transaction

      # Extract date from the beginning of the line
      date_match = line.match(/\A(\d{2}\/[A-Z]{3})/)
      if date_match
        transaction["date"] = parse_spanish_date(date_match[1])
      end

      # Look for CARGOS and ABONOS in the line
      if line.include?("CARGOS") && line.include?("ABONOS")
        # This is a header line, skip
        return transaction
      end

      # For BBVA statements, amounts are typically at the end of the line
      # Look for amounts in the line
      amounts = line.scan(/[\d,]+\.\d{2}/)

      if amounts.length >= 1
        # Get the column positions dynamically from the current page
        cargos_pos, abonos_pos = get_column_positions_for_line(line)

        # Simple rule: CARGOS = expense (-), ABONOS = income (+)
        # Use column position ONLY, not transaction descriptions

        if amounts.length >= 4
          # Four amounts: CARGOS, ABONOS, OPERACIÓN, LIQUIDACIÓN
          cargos_amount = parse_decimal(amounts[0])
          abonos_amount = parse_decimal(amounts[1])

          # Use the non-zero amount as the transaction amount
          if cargos_amount > 0 && abonos_amount == 0
            # Only CARGOS amount present - expense
            transaction = classify_transaction(transaction, -cargos_amount)
          elsif cargos_amount == 0 && abonos_amount > 0
            # Only ABONOS amount present - income
            transaction = classify_transaction(transaction, abonos_amount)
          elsif cargos_amount > 0 && abonos_amount > 0
            # Both present - this shouldn't happen in normal BBVA format
            # Use the larger amount as the transaction
            if cargos_amount > abonos_amount
              transaction = classify_transaction(transaction, -cargos_amount)
            else
              transaction = classify_transaction(transaction, abonos_amount)
            end
          end
        elsif amounts.length >= 3
          # Three amounts: first is transaction, second and third are balances
          first_amount = parse_decimal(amounts[0])
          second_amount = parse_decimal(amounts[1])
          third_amount = parse_decimal(amounts[2])

          # The first amount is the transaction amount
          # We need to determine which column it belongs to based on position
          amount_pos = line.index(amounts[0])

          # Use dynamic column positions with intelligent threshold
          threshold = get_column_threshold(cargos_pos, abonos_pos)
          if amount_pos && amount_pos >= threshold
            # Amount in ABONOS column → income (positive)
            transaction = classify_transaction(transaction, first_amount)
          else
            # Amount in CARGOS column → expense (negative)
            transaction = classify_transaction(transaction, -first_amount)
          end
        elsif amounts.length >= 2
          first_amount = parse_decimal(amounts[0])
          second_amount = parse_decimal(amounts[1])

          # For BBVA statements, we need to determine which amount is the actual transaction
          # and which is a balance amount
          # Typically, the smaller amount is the transaction, the larger is the balance

          if first_amount > 0 && second_amount > 0
            # Both amounts present - determine which is the transaction
            if first_amount < second_amount
              # First amount is smaller - likely the transaction amount in CARGOS column
              transaction = classify_transaction(transaction, -first_amount)
            else
              # Second amount is smaller - likely the transaction amount in ABONOS column
              transaction = classify_transaction(transaction, second_amount)
            end
          elsif first_amount > 0 && second_amount == 0
            # Only first amount present - CARGOS column (expense)
            transaction = classify_transaction(transaction, -first_amount)
          elsif first_amount == 0 && second_amount > 0
            # Only second amount present - ABONOS column (income)
            transaction = classify_transaction(transaction, second_amount)
          end
        else
          # Only one amount - need to determine which column it belongs to
          amount = parse_decimal(amounts[0])

          # Find the position of this amount in the line
          amount_pos = line.index(amounts[0])

          # Use dynamic column positions with intelligent threshold
          threshold = get_column_threshold(cargos_pos, abonos_pos)
          if amount_pos && amount_pos >= threshold
            # Amount in ABONOS column → income (positive)
            transaction = classify_transaction(transaction, amount)
          else
            # Amount in CARGOS column → expense (negative)
            transaction = classify_transaction(transaction, -amount)
          end
        end

        # Extract description (everything between date and amount)
        # Find the second date and skip it
        first_date_pos = line.index(/\d{2}\/[A-Z]{3}/)
        second_date_pos = line.index(/\d{2}\/[A-Z]{3}/, first_date_pos + 1)
        date_end = second_date_pos + 7  # Skip the second date (7 chars: "03/JUL")
        amount_start = line.rindex(amounts.last)

        if date_end && amount_start && amount_start > date_end
          description_text = line[date_end..amount_start-1].strip
          # Clean up the description - remove extra whitespace, amounts, and reference numbers
          description_text = description_text.gsub(/[\d,]+\.\d{2}/, "")  # Remove amounts

          # Extract reference before removing it from description
          # Look for patterns like NOM001, SPEI002, etc.
          reference_match = description_text.match(/\b([A-Z]{3,4}\d+)\b/)
          if reference_match
            transaction["reference"] = reference_match[1]
            # Remove reference from description
            description_text = description_text.gsub(/\b[A-Z]{3,4}\d+\b/, "")
          end

          description_text = description_text.gsub(/\s+/, " ").strip  # Clean whitespace

          # Clean the description to remove bank statement headers
          description_text = clean_transaction_line(description_text)

          transaction["description"] = description_text
        end
      end

      transaction
    end

    def enhance_transaction_with_additional_info(transaction, line)
      # Use the shared concern method but with BBVA-specific cleaning
      transaction = super(transaction, line)

      # Final cleaning of the complete description to remove any remaining header text
      if transaction["description"].present?
        transaction["description"] = clean_transaction_line(transaction["description"])
      end

      transaction
    end

    def is_bank_statement_header?(line)
      # Only filter out lines that are clearly bank statement headers, not transaction lines
      # Be very conservative to avoid filtering valid transactions

      # Check for complete table headers (must contain multiple column headers)
      if line.match?(/FECHA.*SALDO.*OPER.*LIQ.*DESCRIPCIÓN.*REFERENCIA.*CARGOS.*ABONOS.*OPERACIÓN.*LIQUIDACIÓN/i) ||
         line.match?(/SALDO.*OPER.*LIQ.*DESCRIPCIÓN.*REFERENCIA.*CARGOS.*ABONOS.*OPERACIÓN.*LIQUIDACIÓN/i)
        return true
      end

      # Check for page numbers (standalone)
      if line.match?(/^\s*PAGINA\s+\d+\s*\/\s*\d+\s*$/i)
        return true
      end

      # Check for bank address/legal information (standalone lines)
      if line.match?(/^\s*BBVA\s+MEXICO.*INSTITUCION\s+DE\s+BANCA\s+MULTIPLE/i) ||
         line.match?(/^\s*GRUPO\s+FINANCIERO\s+BBVA\s+MEXICO/i) ||
         line.match?(/^\s*ALCALDÍA.*C\.P\./i) ||
         line.match?(/^\s*CIUDAD\s+DE\s+MÉXICO/i) ||
         line.match?(/^\s*MÉXICO.*R\.F\.C\./i)
        return true
      end

      # Check for statement title (standalone)
      if line.match?(/^\s*ESTADO\s+DE\s+CUENTA/i) ||
         line.match?(/^\s*LIBRETÓN\s+PREMIUM/i)
        return true
      end

      # Check for R.F.C. on its own line
      if line.match?(/^\s*R\.F\.C\.\s*$/i)
        return true
      end

      false
    end

    def is_section_break?(line)
      # Check if this line indicates we've moved beyond transaction descriptions
      # Look for patterns that suggest we're in a new section

      # Check for bank address/legal information that appears after transactions
      if line.match?(/BBVA\s+MEXICO.*INSTITUCION\s+DE\s+BANCA\s+MULTIPLE/i) ||
         line.match?(/GRUPO\s+FINANCIERO\s+BBVA\s+MEXICO/i) ||
         line.match?(/ALCALDÍA.*C\.P\./i) ||
         line.match?(/CIUDAD\s+DE\s+MÉXICO/i) ||
         line.match?(/MÉXICO.*R\.F\.C\./i)
        return true
      end

      # Check for statement footer information
      if line.match?(/ESTADO\s+DE\s+CUENTA/i) ||
         line.match?(/LIBRETÓN\s+PREMIUM/i) ||
         line.match?(/PAGINA\s+\d+\s*\/\s*\d+/i)
        return true
      end

      # Check for table headers that appear after transactions
      if line.match?(/FECHA.*SALDO.*OPER.*LIQ.*DESCRIPCIÓN.*REFERENCIA.*CARGOS.*ABONOS.*OPERACIÓN.*LIQUIDACIÓN/i) ||
         line.match?(/SALDO.*OPER.*LIQ.*DESCRIPCIÓN.*REFERENCIA.*CARGOS.*ABONOS.*OPERACIÓN.*LIQUIDACIÓN/i)
        return true
      end

      # Check for R.F.C. on its own line
      if line.match?(/^\s*R\.F\.C\.\s*$/i)
        return true
      end

      # Check for account/client information that appears in the middle of transaction descriptions
      if line.match?(/No\.deCuenta.*No\.deCliente.*FECHA.*SALDO.*OPER.*LIQ.*DESCRIPCIÓN.*REFERENCIA.*CARGOS.*ABONOS.*OPERACIÓN.*LIQUIDACIÓN/i)
        return true
      end

      false
    end

    def clean_transaction_line(line)
      # Remove bank statement header patterns from transaction lines
      # This helps clean up lines that contain both transaction info and headers
      # BE CONSERVATIVE to avoid removing valid transaction data

      cleaned = line.dup

      # Remove account/client information patterns (more flexible matching)
      cleaned = cleaned.gsub(/No\.deCuenta\s+\d+.*?No\.deCliente\s+\d+/, "")
      cleaned = cleaned.gsub(/No\.deCuenta\s+No\.deCliente\s+\d+/, "")
      cleaned = cleaned.gsub(/No\.deCuenta\s+No\.deCliente/, "")
      cleaned = cleaned.gsub(/No\.deCuenta\s+\d+/, "")
      cleaned = cleaned.gsub(/No\.deCliente\s+\d+/, "")

      # Remove bank statement header patterns (consolidated)
      header_patterns = [
        /FECHA.*?SALDO.*?OPER.*?LIQ.*?DESCRIPCIÓN.*?REFERENCIA.*?CARGOS.*?ABONOS.*?OPERACIÓN.*?LIQUIDACIÓN/,
        /SALDO.*?OPER.*?LIQ.*?DESCRIPCIÓN.*?REFERENCIA.*?CARGOS.*?ABONOS.*?OPERACIÓN.*?LIQUIDACIÓN/,
        /\bFECHA\s+SALDO\s+OPER\s+LIQ\s+DESCRIPCIÓN\s+REFERENCIA\s+CARGOS\s+ABONOS\s+OPERACIÓN\s+LIQUIDACIÓN\b/,
        /\bSALDO\s+OPER\s+LIQ\s+DESCRIPCIÓN\s+REFERENCIA\s+CARGOS\s+ABONOS\s+OPERACIÓN\s+LIQUIDACIÓN\b/,
        /\s+FECHA\s+.*?SALDO\s+.*?OPER\s+.*?LIQ\s+.*?DESCRIPCIÓN\s+.*?REFERENCIA\s+.*?CARGOS\s+.*?ABONOS\s+.*?OPERACIÓN\s+.*?LIQUIDACIÓN\s*$/,
        /\s+SALDO\s+.*?OPER\s+.*?LIQ\s+.*?DESCRIPCIÓN\s+.*?REFERENCIA\s+.*?CARGOS\s+.*?ABONOS\s+.*?OPERACIÓN\s+.*?LIQUIDACIÓN\s*$/,
        /\s+FECHA\s+SALDO\s+OPER\s+LIQ\s+DESCRIPCIÓN\s+REFERENCIA\s+CARGOS\s+ABONOS\s+OPERACIÓN\s+LIQUIDACIÓN\s*/,
        /\s+SALDO\s+OPER\s+LIQ\s+DESCRIPCIÓN\s+REFERENCIA\s+CARGOS\s+ABONOS\s+OPERACIÓN\s+LIQUIDACIÓN\s*/
      ]

      header_patterns.each do |pattern|
        cleaned = cleaned.gsub(pattern, "")
      end

      # Remove very long account numbers (15+ digits) but preserve shorter reference numbers
      cleaned = cleaned.gsub(/\b\d{15,}\b/, "")  # Only remove very long numbers (likely account numbers)

      # Clean up extra whitespace
      cleaned = cleaned.gsub(/\s+/, " ").strip

      cleaned
    end

    def clean_description(text)
      # Use BBVA-specific cleaning
      clean_transaction_line(text)
    end

    def extract_statement_period(lines)
      # Look for statement period information
      period_info = {}

      lines.each do |line|
        if line.include?("Periodo:") || line.include?("Del:") || line.include?("Al:")
          # Extract period information if available
          if line.include?("Periodo:")
            period_info["period_description"] = line.split("Periodo:").last&.strip
          end
        end
      end

      period_info
    end

    def extract_year_from_statement_period
      # Look for the statement period line to extract the year
      lines = @text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      lines.each do |line|
        if line.include?("Periodo") && line.match(/DEL\s+\d{2}\/\d{2}\/(\d{4})/)
          return Regexp.last_match(1)
        end
      end

      # Fallback to current year if period not found
      Date.current.year.to_s
    end

    def get_column_positions_for_line(transaction_line)
      # Find the header line that corresponds to this transaction
      # Look for the most recent header before this transaction
      lines = @text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      # Find the transaction line index
      transaction_index = lines.find_index(transaction_line)
      return [ 83, 96 ] unless transaction_index # fallback to default positions

      # Look backwards from the transaction to find the most recent header
      (transaction_index - 1).downto(0) do |i|
        line = lines[i]
        if line.include?("CARGOS") && line.include?("ABONOS")
          cargos_pos = line.index("CARGOS")
          abonos_pos = line.index("ABONOS")
          return [ cargos_pos, abonos_pos ] if cargos_pos && abonos_pos
        end
      end

      # For test data or simple headers, use a different approach
      # Look for any line that contains CARGOS and ABONOS in any order
      lines.each do |line|
        if line.include?("CARGOS") && line.include?("ABONOS")
          cargos_pos = line.index("CARGOS")
          abonos_pos = line.index("ABONOS")
          return [ cargos_pos, abonos_pos ] if cargos_pos && abonos_pos
        end
      end

      # Fallback to default positions if no header found
      [ 83, 96 ]
    end

    def get_column_threshold(cargos_pos, abonos_pos)
      # Calculate a more intelligent threshold between CARGOS and ABONOS columns
      # Use the middle point between the end of CARGOS and start of ABONOS
      cargos_end = cargos_pos + 6  # 'CARGOS' is 6 characters

      # Use the middle point between CARGOS end and ABONOS start as the threshold
      middle_point = (cargos_end + abonos_pos) / 2
      middle_point
    end
  end
end
