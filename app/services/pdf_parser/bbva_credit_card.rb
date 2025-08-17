# app/services/pdf_parser/bbva_credit_card.rb
module PdfParser
  class BbvaCreditCard < Base
    # BBVA Credit Card specific patterns
    DATE_PATTERN = /(\d{2})\/(\d{2})\/(\d{2,4})/  # Handle both 2-digit and 4-digit years
    AMOUNT_PATTERN = /([\d,]+\.?\d*)/  # Match amounts like "385.00", "1,861.52"

    # Table structure identifiers
    TABLE_HEADERS = [
      "FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS",
      "FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS"
    ]

    # Transaction section identifiers
    TRANSACTION_SECTIONS = [ "Movimientos Efectuados" ]
    FINANCIAL_SUMMARY_SECTIONS = [ "TOTAL IMPORTES", "Resumen Informativo", "Estado de Cuenta" ]

    def parse(text, context: {})
      lines = text.to_s.split(/\r?\n/).map(&:strip).reject(&:empty?)

      # Extract transaction and financial summary sections
      transaction_text = extract_transaction_sections(lines)
      financial_summary_text = extract_financial_summary_sections(lines)

      # Combine for AI analysis
      combined_text = combine_sections_for_ai(transaction_text, financial_summary_text)

      # Try AI parsing first
      ai_result = parse_with_ai(combined_text, context)

      if ai_result && ai_result["transactions"]&.any?
        # AI parsing successful
        ai_result["extraction_source"] = "bbva_credit_card_parser_ai"
        ai_result
      else
        # Fallback to deterministic parsing
        puts "AI parsing failed, falling back to deterministic parser"
        parse_with_deterministic_fallback(lines)
      end
    end

    private

    def extract_transaction_sections(lines)
      transaction_lines = []
      in_transaction_section = false

      lines.each do |line|
        # Start of transaction section
        if TRANSACTION_SECTIONS.any? { |identifier| line.include?(identifier) }
          in_transaction_section = true
          transaction_lines << line
          next
        end

        # End of transaction section
        if in_transaction_section && line.match?(/^TOTAL IMPORTES|^Resumen Informativo|^Detalle de Transacciones/)
          break
        end

        # Collect transaction section lines
        if in_transaction_section
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
        if FINANCIAL_SUMMARY_SECTIONS.any? { |identifier| line.include?(identifier) }
          in_summary_section = true
          summary_lines << line
          next
        end

        # End of financial summary section
        if in_summary_section && line.match?(/^Si te uniste al Plan de Apoyo|^bbva\.mx/)
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
        BBVA Credit Card Statement - Transactions and Financial Summaries

        === TRANSACTIONS ===
        #{transaction_text}

        === FINANCIAL SUMMARIES ===
        #{financial_summary_text}

        Please parse the above BBVA credit card statement and extract:
        1. All transactions with dates, descriptions, amounts, and types
        2. Financial summaries including opening/closing balances, totals, fees, and installment information

        Return the data in JSON format with transactions and financial_summaries arrays.
      TEXT
    end

    def parse_with_ai(text, context)
      # Create a simple prompt for BBVA parsing
      prompt = build_bbva_prompt(text)

      begin
        # For now, let's just return nil to test the fallback
        # In production, this would call the AI service
        puts "AI parsing would be called here with prompt length: #{prompt.length}"
        puts "Prompt preview: #{prompt[0..200]}..."
        nil
      rescue => e
        puts "AI parsing failed: #{e.message}"
        nil
      end
    end

    def build_bbva_prompt(text)
      <<~PROMPT
        Parse the following BBVA credit card statement text into JSON format.

        Extract:
        1. All transactions with dates, descriptions, amounts, and types
        2. Financial summaries including balances, fees, and totals

        For transactions, use:
        - transaction_type: "income" for credits, "variable_expense" for charges
        - bank_entry_type: "credit" for credits, "debit" for charges
        - amount: negative for expenses, positive for income

        For financial summaries, use:
        - type: "balance", "fee", "interest", "commission", "installment", "total", or "other"

        Return JSON with transactions and financial_summaries arrays.

        Statement text:
        #{text}
      PROMPT
    end

    def parse_with_deterministic_fallback(lines)
      # Keep the existing deterministic logic as fallback
      transactions = []

      # Find and parse all transaction sections
      transaction_sections = find_transaction_sections(lines)

      # Merge sections that belong to the same card
      transaction_sections = merge_card_sections(transaction_sections)

      transaction_sections.each do |section|
        section_transactions = parse_transaction_section(section)
        transactions.concat(section_transactions)
      end

      # Only look for individual transaction lines if we didn't find any in sections
      if transactions.empty?
        individual_transactions = parse_individual_lines(lines)
        transactions.concat(individual_transactions)
      end

      # Remove duplicates and sort by date
      transactions = deduplicate_transactions(transactions)
      transactions.sort_by! { |t| Date.parse(t["date"]) }

      {
        "opening_balance" => extract_balance_from_lines(lines, "opening"),
        "closing_balance" => extract_balance_from_lines(lines, "closing"),
        "transactions" => transactions,
        "extraction_source" => "bbva_credit_card_parser_deterministic_fallback"
      }
    end

    def find_transaction_sections(lines)
      sections = []
      current_section = []
      in_transaction_section = false
      found_headers = false
      current_card = nil

      lines.each do |line|
        # Check if we're entering a transaction section
        if TRANSACTION_SECTIONS.any? { |identifier| line.include?(identifier) }
          if current_section.any?
            sections << current_section
          end
          current_section = [ line ]
          in_transaction_section = true
          found_headers = false
          current_card = nil
          next
        end

        # Check if we're leaving a transaction section
        # Only end on clear section boundaries, not on summary lines within the section
        if in_transaction_section && line.match?(/^Resumen Informativo|^Detalle de Transacciones|^Si te uniste al Plan de Apoyo/)
          sections << current_section
          current_section = []
          in_transaction_section = false
          found_headers = false
          current_card = nil
          next
        end

        # Check if we found table headers
        if in_transaction_section && !found_headers && line.match?(/FECHA AUTORIZACION.*FECHA APLICACION.*CONCEPTO.*R\.F\.C\./)
          found_headers = true
        end

        # Extract card number from "Tarjeta Titular" lines
        if line.include?("Tarjeta Titular")
          card_match = line.match(/Tarjeta Titular (\d{4} \d{4} \d{4} \d{4})/)
          if card_match
            new_card = card_match[1]
            # If this is a continuation of the same card, don't start a new section
            if current_card && new_card == current_card && found_headers
              # This is a continuation, add to current section
              current_section << line
            else
              # This is a new card, start new section
              if current_section.any?
                sections << current_section
              end
              current_section = [ line ]
              found_headers = false
              current_card = new_card
            end
          else
            # No card number found, treat as continuation if we have headers
            if found_headers && current_section.length > 2
              current_section << line
            else
              if current_section.any?
                sections << current_section
              end
              current_section = [ line ]
              found_headers = false
            end
          end
        elsif in_transaction_section
          current_section << line
        end
      end

      # Add the last section if it exists
      if current_section.any?
        sections << current_section
      end

      sections
    end

    def merge_card_sections(sections)
      merged_sections = []
      card_sections = {}
      header_section = nil

      puts "=== DEBUG: Section Merging ==="
      puts "Original sections: #{sections.length}"
      sections.each_with_index do |section, i|
        puts "Section #{i}: #{section.first} (#{section.length} lines)"
        puts "  Lines in section #{i}:"
        section.each_with_index { |line, j| puts "    #{j}: #{line}" }
      end

      sections.each do |section|
        # Check if this is a header section
        if section.first.include?("Movimientos Efectuados")
          puts "Found header section, storing for later merge"
          header_section = section
          next
        end

        # Extract card number from the first line of the section
        # Handle both "Tarjeta Titular XXXX XXXX XXXX XXXX" and "Tarjeta Titular XXXX XXXX XXXX XXXX (continued)"
        card_match = section.first.match(/Tarjeta Titular (\d{4} \d{4} \d{4} \d{4})/)
        if card_match
          card_number = card_match[1]
          puts "Processing section for card: #{card_number}"

          if card_sections[card_number]
            puts "Merging with existing section for card #{card_number}"
            card_sections[card_number].concat(section)
          else
            puts "Creating new section for card #{card_number}"
            card_sections[card_number] = section
          end
        else
          # Non-card sections go as-is
          puts "Adding non-card section as-is"
          merged_sections << section
        end
      end

      # Add all merged card sections
      card_sections.each do |card_number, section|
        puts "Adding merged section for card #{card_number} with #{section.length} lines"
        merged_sections << section
      end

      # Merge header section with the first card section if we have one
      if header_section && merged_sections.any?
        first_card_section = merged_sections.first
        if first_card_section.first.include?("Tarjeta Titular")
          puts "Merging header section with first card section"
          merged_sections[0] = header_section + first_card_section
        end
      end

      puts "Final merged sections: #{merged_sections.length}"
      merged_sections.each_with_index do |section, i|
        puts "Merged section #{i}: #{section.first} (#{section.length} lines)"
        puts "  Lines in merged section #{i}:"
        section.each_with_index { |line, j| puts "    #{j}: #{line}" }
      end
      puts "====================================="

      merged_sections
    end

    def parse_transaction_section(section_lines)
      transactions = []

      puts "=== DEBUG: Parsing Section ==="
      puts "Section first line: #{section_lines.first}"
      puts "Section lines: #{section_lines.length}"

      # Look for table structure with proper headers
      if has_table_structure?(section_lines)
        puts "Found table structure, parsing with table parser"
        transactions = parse_table_structure(section_lines)
      else
        puts "No table structure, parsing with free-form parser"
        # Try to parse as free-form transactions
        transactions = parse_free_form_transactions(section_lines)
      end

      puts "Parsed #{transactions.length} transactions from this section"
      transactions.each_with_index do |tx, i|
        puts "  #{i+1}. #{tx['date']} | #{tx['description']} | #{tx['amount']}"
      end
      puts "====================================="

      transactions
    end

    def has_table_structure?(lines)
      # Check if we have the typical BBVA table headers
      has_headers = lines.any? do |line|
        TABLE_HEADERS.any? do |header|
          clean_line = line.gsub(/\s*\|\s*/, "|").gsub(/\s+/, " ")
          clean_header = header.gsub(/\s+/, " ")
          clean_line.include?(clean_header)
        end
      end

      # Also check if we have pipe-separated lines that look like transactions
      # This handles cases like the first section with SIX PREMIER transactions
      has_pipe_separated_lines = lines.any? do |line|
        if line.include?("|")
          parts = line.split("|").map(&:strip)
          # Check if this looks like a transaction line (has date, description, and amount)
          parts.length >= 6 &&
          parts[0].match?(DATE_PATTERN) &&
          (parts[5].match?(AMOUNT_PATTERN) || parts[6]&.match?(AMOUNT_PATTERN))
        else
          false
        end
      end

      # Check if we have multiple transaction-like lines (this is the most important check)
      has_transaction_lines = lines.count do |line|
        # Look for lines that have both date and amount patterns
        line.match?(DATE_PATTERN) && line.match?(AMOUNT_PATTERN)
      end >= 3  # At least 3 transaction-like lines

      puts "Table structure check: headers=#{has_headers}, pipe_separated=#{has_pipe_separated_lines}, transaction_lines=#{has_transaction_lines}"

      has_headers || has_pipe_separated_lines || has_transaction_lines
    end

    def parse_table_structure(lines)
      transactions = []

      puts "=== DEBUG: Table Structure Parsing ==="
      puts "Total lines: #{lines.length}"
      lines.each_with_index { |line, i| puts "Line #{i}: #{line}" }

      # Find the header line to understand column positions
      header_line = lines.find { |line| TABLE_HEADERS.any? { |header| line.include?(header) } }
      puts "Header line found: #{header_line ? 'Yes' : 'No'}"
      if header_line
        puts "Header: #{header_line}"
      end

      # Parse each line that looks like a transaction
      lines.each do |line|
        puts "Processing line: #{line}"

        if line == header_line
          puts "  -> Skipping header line"
          next
        end

        if line.match?(/^TOTAL|^Iva:|^Interes:|^Comisiones:|^Capital:|^Capital de promoción:|^Pago excedente:/)
          puts "  -> Skipping summary line"
          next
        end

        transaction = parse_table_line(line)
        if transaction
          puts "  -> Parsed transaction: #{transaction['description']} | #{transaction['amount']}"
          transactions << transaction
        else
          puts "  -> Failed to parse transaction"
        end
      end

      puts "Total transactions parsed: #{transactions.length}"
      puts "====================================="

      transactions
    end

    def parse_table_line(line)
      # Handle pipe-separated format (most common for BBVA)
      if line.include?("|")
        return parse_pipe_separated_line(line)
      end

      # Handle other formats
      parse_other_formats(line)
    end

    def parse_pipe_separated_line(line)
      # Split by pipe and preserve empty fields
      parts = line.split("|").map(&:strip)

      # BBVA table can have 6-7 columns, with some columns potentially empty
      return nil if parts.length < 6

      # Extract relevant parts
      auth_date = parts[0]
      app_date = parts[1]
      concept = parts[2]
      rfc = parts[3] || ""
      reference = parts[4] || ""
      cargos = parts[5] || ""
      abonos = parts[6] || ""

      # Determine which column has the amount and transaction type
      if abonos.present? && abonos.match(AMOUNT_PATTERN)
        # This is a credit transaction (IMPORTE ABONOS)
        amount_str = abonos.match(AMOUNT_PATTERN)[1]
        amount = amount_str.gsub(",", "").to_f
        transaction_type = "income"
        bank_entry_type = "credit"
      elsif cargos.present? && cargos.match(AMOUNT_PATTERN)
        # This is a debit transaction (IMPORTE CARGOS)
        amount_str = cargos.match(AMOUNT_PATTERN)[1]
        amount = -amount_str.gsub(",", "").to_f  # Make negative for expenses
        transaction_type = "variable_expense"
        bank_entry_type = "debit"
      else
        return nil
      end

      # Extract date from authorization date
      date_match = auth_date.match(DATE_PATTERN)
      return nil unless date_match

      # Extract merchant from concept
      merchant = extract_merchant(concept)

      # Clean up reference
      reference = reference.present? ? reference : nil

      {
        "date" => normalize_date(date_match[1], date_match[2], date_match[3]),
        "description" => concept.strip,
        "amount" => sprintf("%.2f", amount),
        "transaction_type" => transaction_type,
        "bank_entry_type" => bank_entry_type,
        "merchant" => merchant,
        "reference" => reference,
        "rfc" => rfc,
        "category" => "Sin Categorizar",
        "sub_category" => nil,
        "raw_text" => line,
        "confidence" => 0.95,
        "category_confidence" => 0.8,
        "transaction_type_confidence" => 0.98
      }
    end

    def parse_other_formats(line)
      # Look for date and amount patterns
      date_match = line.match(DATE_PATTERN)
      return nil unless date_match

      # Look for amounts in the line
      amounts = line.scan(AMOUNT_PATTERN).flatten
      return nil if amounts.empty?

      # Determine transaction type from context
      if line.downcase.include?("importe cargos") || line.downcase.include?("cargos")
        # This is an expense
        amount_str = amounts.first
        amount = -amount_str.gsub(",", "").to_f
        transaction_type = "variable_expense"
        bank_entry_type = "debit"
      elsif line.downcase.include?("importe abonos") || line.downcase.include?("abonos")
        # This is income
        amount_str = amounts.first
        amount = amount_str.gsub(",", "").to_f
        transaction_type = "income"
        bank_entry_type = "credit"
      else
        # Default to expense if no clear context
        amount_str = amounts.first
        amount = -amount_str.gsub(",", "").to_f
        transaction_type = "variable_expense"
        bank_entry_type = "debit"
      end

      # Extract description
      description = extract_description(line, date_match)

      # Extract additional info
      reference = extract_reference(line)
      merchant = extract_merchant(description)

      {
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
        "confidence" => 0.85,
        "category_confidence" => 0.7,
        "transaction_type_confidence" => 0.9
      }
    end

    def parse_free_form_transactions(lines)
      transactions = []

      lines.each do |line|
        next if line.match?(/^TOTAL|^Iva:|^Interes:|^Comisiones:|^Capital:|^Capital de promoción:|^Pago excedente:/)

        # Look for lines with date and amount patterns
        date_match = line.match(DATE_PATTERN)
        next unless date_match

        # Look for amounts in the line
        amounts = line.scan(AMOUNT_PATTERN).flatten
        next if amounts.empty?

        # Extract description
        description = extract_description(line, date_match)

        # Process each amount found
        amounts.each do |amount_str|
          amount = amount_str.gsub(",", "").to_f

          # Determine if this is a charge or credit based on context
          transaction_type, bank_entry_type = determine_type_from_context(line, amount)

          # Ensure expense transactions have negative amounts
          if transaction_type == "variable_expense" && amount > 0
            amount = -amount
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
            "confidence" => 0.8,
            "category_confidence" => 0.6,
            "transaction_type_confidence" => 0.9
          }
        end
      end

      transactions
    end

    def parse_individual_lines(lines)
      transactions = []

      lines.each do |line|
        # Look for lines that have both date and amount but weren't caught by section parsing
        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        next unless date_match && amount_match

        # Skip if this looks like a header or summary line
        next if line.match?(/^TOTAL|^Iva:|^Interes:|^Comisiones:|^Capital:|^Capital de promoción:|^Pago excedente:|^Estado de Cuenta|^Tarjeta Titular|^Resumen Informativo/)

        # Skip summary lines that aren't actual transactions
        next if line.match?(/COMISION ANUALIDAD.*CARGO INICIAL|PARCIALIDAD|FALTAN|SALDO ACTUAL/)
        next if line.match?(/COMISION ANUALIDAD.*01 de 03/)

        # Skip installment summary lines (these contain dates and amounts but aren't transactions)
        next if line.match?(/\d{2} de \d{2}/)  # Pattern like "05 de 12", "10 de 12"
        next if line.match?(/CARGO INICIAL|PARCIALIDAD|FALTAN|SALDO ACTUAL/)
        next if line.match?(/Resumen Informativo de sus Cargos sin Intereses/)

        # Skip lines that are already parsed by table parser (pipe-separated with proper structure)
        next if line.include?("|") && line.split("|").length >= 7

        # Skip lines that look like installment payment summaries from the summary section
        # These are in the "Resumen Informativo" section, not the "Movimientos Efectuados" section
        next if line.match?(/VIVA AEROBUS.*\d{2} de \d{2}/) && !line.include?("|")
        next if line.match?(/SRIA FINANZAS.*\d{2} de \d{2}/) && !line.include?("|")

        # Skip lines that are clearly from the installment summary section
        next if line.match?(/FECHA TRANSACCION.*NOMBRE DEL CARGO.*CARGO INICIAL.*PARCIALIDAD.*FALTAN.*SALDO ACTUAL/)

        amount = amount_match[1].gsub(",", "").to_f
        description = extract_description(line, date_match)

        # Determine transaction type from context
        transaction_type, bank_entry_type = determine_type_from_context(line, amount)

        # Ensure expense transactions have negative amounts
        if transaction_type == "variable_expense" && amount > 0
          amount = -amount
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
          "confidence" => 0.75,
          "category_confidence" => 0.6,
          "transaction_type_confidence" => 0.85
        }
      end

      transactions
    end

    def find_missed_transactions(lines, existing_transactions)
      missed = []

      lines.each do |line|
        # Look for lines that have both date and amount but weren't caught by section parsing
        date_match = line.match(DATE_PATTERN)
        amount_match = line.match(AMOUNT_PATTERN)

        next unless date_match && amount_match

        # Skip if this looks like a header or summary line
        next if line.match?(/^TOTAL|^Iva:|^Interes:|^Comisiones:|^Capital:|^Capital de promoción:|^Pago excedente:|^Estado de Cuenta|^Tarjeta Titular|^Resumen Informativo/)

        # Skip summary lines that aren't actual transactions
        next if line.match?(/COMISION ANUALIDAD.*CARGO INICIAL|PARCIALIDAD|FALTAN|SALDO ACTUAL/)
        next if line.match?(/COMISION ANUALIDAD.*01 de 03/)

        # Skip installment summary lines (these contain dates and amounts but aren't transactions)
        next if line.match?(/\d{2} de \d{2}/)  # Pattern like "05 de 12", "10 de 12"
        next if line.match?(/CARGO INICIAL|PARCIALIDAD|FALTAN|SALDO ACTUAL/)
        next if line.match?(/Resumen Informativo de sus Cargos sin Intereses/)

        # Skip lines that are already parsed by table parser (pipe-separated with proper structure)
        next if line.include?("|") && line.split("|").length >= 7

        # Skip lines that look like installment payment summaries from the summary section
        # These are in the "Resumen Informativo" section, not the "Movimientos Efectuados" section
        next if line.match?(/VIVA AEROBUS.*\d{2} de \d{2}/) && !line.include?("|")
        next if line.match?(/SRIA FINANZAS.*\d{2} de \d{2}/) && !line.include?("|")

        # Skip lines that are clearly from the installment summary section
        next if line.match?(/FECHA TRANSACCION.*NOMBRE DEL CARGO.*CARGO INICIAL.*PARCIALIDAD.*FALTAN.*SALDO ACTUAL/)

        # Check if this transaction is already captured by existing transactions
        # Use a more flexible matching to avoid duplicates
        existing_descriptions = existing_transactions.map { |t| t["description"] }
        line_description = extract_description(line, date_match)

        # Skip if we already have a transaction with similar description and date
        next if existing_descriptions.any? { |desc|
          # Check if the first few words match and the date matches
          desc_words = desc.split.first(3).join(" ").downcase
          line_words = line_description.split.first(3).join(" ").downcase
          desc_words == line_words &&
          existing_transactions.any? { |t| t["date"] == normalize_date(date_match[1], date_match[2], date_match[3]) }
        }

        # Also check for exact amount matches on the same date
        line_amount = amount_match[1].gsub(",", "").to_f.abs
        line_date = normalize_date(date_match[1], date_match[2], date_match[3])
        next if existing_transactions.any? { |t|
          t["date"] == line_date && t["amount"].to_f.abs == line_amount
        }

        amount = amount_match[1].gsub(",", "").to_f
        description = extract_description(line, date_match)

        # Determine transaction type from context
        transaction_type, bank_entry_type = determine_type_from_context(line, amount)

        # Ensure expense transactions have negative amounts
        if transaction_type == "variable_expense" && amount > 0
          amount = -amount
        end

        # Extract additional info
        reference = extract_reference(line)
        merchant = extract_merchant(description)

        missed << {
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
          "confidence" => 0.75,
          "category_confidence" => 0.6,
          "transaction_type_confidence" => 0.85
        }
      end

      missed
    end

    def extract_description(line, date_match)
      # Remove the date from the line
      line_without_date = line.sub(DATE_PATTERN, "")

      # Remove amount patterns
      line_without_amounts = line_without_date.gsub(AMOUNT_PATTERN, "")

      # Remove common banking terms that shouldn't be in description
      line_cleaned = line_without_amounts
        .gsub(/IMPORTE CARGOS:\s*/, "")
        .gsub(/IMPORTE ABONOS:\s*/, "")
        .gsub(/\|\s*/, " ")  # Remove pipe separators
        .gsub(/\s+/, " ")    # Normalize whitespace
        .strip

      # Take only the first meaningful part (before any extra banking info)
      parts = line_cleaned.split(/\s{2,}/)
      parts.first || line_cleaned
    end

    def determine_type_from_context(line, amount)
      line_lower = line.downcase

      # Check for specific transaction types first
      if line_lower.include?("pago tdc") || line_lower.include?("payment")
        return "income", "credit"
      elsif line_lower.include?("anualidad") || line_lower.include?("fee")
        return "variable_expense", "debit"
      elsif line_lower.include?("cargos") || line_lower.include?("cargo")
        return "variable_expense", "debit"
      elsif line_lower.include?("abonos") || line_lower.include?("abono")
        return "income", "credit"
      elsif line_lower.include?("six premier") || line_lower.include?("netflix") || line_lower.include?("amazon") ||
            line_lower.include?("google") || line_lower.include?("playtomic") || line_lower.include?("melimas") ||
            line_lower.include?("bestbuy") || line_lower.include?("viva aerobus") || line_lower.include?("sria finanzas") ||
            line_lower.include?("conekta") || line_lower.include?("parco")
        # These are all expenses
        return "variable_expense", "debit"
      else
        # Default based on amount sign
        if amount < 0
          return "variable_expense", "debit"
        else
          return "income", "credit"
        end
      end
    end

    def extract_reference(line)
      # Look for reference patterns in order of preference
      reference_patterns = [
        /\b(\d{9,})\b/,  # 9+ digit numbers (like 300843361)
        /\b([A-Z]{2,}\d{3,})\b/,  # Letters + numbers (like A5FB3)
        /\b(\*{4}\d{4})\b/,  # Masked card numbers (like ****7465)
        /\b(\d{6,})\b/  # 6+ digit numbers
      ]

      reference_patterns.each do |pattern|
        match = line.match(pattern)
        if match
          reference = match[1]
          # Skip if it's clearly a date or amount
          next if reference.match?(/^\d{2}$/) || reference.match?(/^\d{4}$/)

          # For BESTBUY transactions, extract just the numeric part
          if reference.start_with?("BESTBUYCOM")
            numeric_part = reference.gsub("BESTBUYCOM", "")
            return numeric_part if numeric_part.length >= 6
          end

          return reference
        end
      end

      nil
    end

    def extract_merchant(description)
      # Handle specific merchant cases first
      description_lower = description.downcase

      if description_lower.include?("bestbuy")
        return "BESTBUY"
      elsif description_lower.include?("netflix")
        return "NETFLIX"
      elsif description_lower.include?("amazon")
        return "AMAZON"
      elsif description_lower.include?("google")
        return "GOOGLE"
      elsif description_lower.include?("playtomic")
        return "PLAYTOMIC"
      elsif description_lower.include?("melimas")
        return "MELIMAS"
      elsif description_lower.include?("viva aerobus")
        return "VIVA AEROBUS"
      elsif description_lower.include?("sria finanzas")
        return "SRIA FINANZAS"
      elsif description_lower.include?("conekta")
        return "CONEKTA"
      elsif description_lower.include?("parco")
        return "PARCO"
      elsif description_lower.include?("six premier")
        return "SIX PREMIER"
      end

      # Common merchant patterns for other cases
      merchant_patterns = [
        /^([A-Z\s]+)\s/,  # All caps words at start
        /([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/,  # Proper case words
        /([A-Z]{2,}(?:\s+[A-Z]{2,})*)/  # Multiple all caps words
      ]

      merchant_patterns.each do |pattern|
        match = description.match(pattern)
        if match && match[1].length > 2
          return match[1].strip
        end
      end

      # Fallback: first few words of description
      description.split(/\s+/).first(3).join(" ")
    end

    def deduplicate_transactions(transactions)
      # Group by date, description, and absolute amount to find duplicates
      grouped = transactions.group_by { |t| [ t["date"], t["description"], t["amount"].to_f.abs ] }

      # Take only the first occurrence of each unique transaction
      # Prefer the one with the correct sign based on context
      grouped.values.map do |duplicates|
        if duplicates.length == 1
          duplicates.first
        else
          # If we have duplicates with different signs, choose the one that makes sense
          # Look for the one that matches the expected pattern
          if duplicates.any? { |t| t["raw_text"].include?("IMPORTE CARGOS") }
            duplicates.find { |t| t["raw_text"].include?("IMPORTE CARGOS") }
          elsif duplicates.any? { |t| t["raw_text"].include?("IMPORTE ABONOS") }
            duplicates.find { |t| t["raw_text"].include?("IMPORTE ABONOS") }
          else
            # For pipe-separated lines, prefer the one with the cleaner description
            pipe_separated = duplicates.find { |t| t["raw_text"].include?("|") }
            if pipe_separated
              pipe_separated
            else
              # Default to the first one
              duplicates.first
            end
          end
        end
      end
    end

    def normalize_date(day, month, year)
      # Convert DD/MM/YY to YYYY-MM-DD
      full_year = year.to_i < 50 ? "20#{year}" : "19#{year}"
      "#{full_year}-#{month}-#{day}"
    end

    def extract_balance_from_lines(lines, balance_type)
      # Simple balance extraction from lines
      lines.each do |line|
        if balance_type == "opening" && line.include?("Saldo Nuevo")
          # Extract opening balance
          if match = line.match(/(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        elsif balance_type == "closing" && line.include?("Saldo Nuevo")
          # Extract closing balance
          if match = line.match(/(\d{1,3}(?:,\d{3})*\.?\d*)/)
            return match[1].gsub(",", "").to_f
          end
        end
      end
      nil
    end
  end
end
