# lib/table_reconstructor.rb
# Reconstruct fragmented transaction tables from OCR data

class TableReconstructor
  def self.reconstruct_transactions(text)
    new(text).reconstruct
  end

  def initialize(text)
    @text = text
  end

  def reconstruct
    all_transactions = []

    # Find ALL transaction table sections in the text
    table_sections = find_all_transaction_sections

    # Extract ALL descriptions from all sections
    all_descriptions = []
    table_sections.each do |table_section|
      descriptions = extract_transaction_descriptions(table_section)
      all_descriptions.concat(descriptions)
    end

    # Extract ALL amounts from all sections
    all_amounts = []
    table_sections.each do |table_section|
      amounts = extract_amounts_and_balances(table_section)
      all_amounts.concat(amounts)
    end


    # Try to match descriptions with amounts
    matched_transactions = match_transactions(all_descriptions, all_amounts)

    # Remove duplicates based on date + description + amount
    matched_transactions.uniq { |txn| [ txn[:date], txn[:description], txn[:amount] ] }
  end

  def find_all_transaction_sections
    sections = []

    # Find all "FECHA" occurrences (start of transaction tables)
    fecha_positions = []
    start_pos = 0
    while (pos = @text.index("FECHA", start_pos))
      fecha_positions << pos
      start_pos = pos + 1
    end

    # For each FECHA position, find the corresponding table section
    fecha_positions.each do |fecha_pos|
      # Look for the end of this table section
      table_end = find_table_end(fecha_pos)

      if table_end > fecha_pos
        table_section = @text[fecha_pos...table_end]
        sections << table_section
      end
    end

    sections
  end

  def find_table_end(start_pos)
    # Look for common table end markers
    end_markers = [ "TOTAL", "SALDO FINAL", "Página", "PAGINA", "ESTADO DE CUENTA" ]

    earliest_end = @text.length

    end_markers.each do |marker|
      pos = @text.index(marker, start_pos)
      if pos && pos < earliest_end
        earliest_end = pos
      end
    end

    # If no end marker found, look for the next FECHA or end of text
    next_fecha = @text.index("FECHA", start_pos + 100)
    if next_fecha && next_fecha < earliest_end
      earliest_end = next_fecha
    end

    earliest_end
  end

  private

  def extract_transaction_descriptions(table_section)
    descriptions = []

    # Look for lines with dates and descriptions
    table_section.lines.each do |line|
      line = line.strip
      next if line.empty?

      # Match date patterns
      if line.match?(/\d{2}-[A-Z]{3}-\d{4}/)
        date = line.match(/\d{2}-[A-Z]{3}-\d{4}/)[0]

        # Extract description (everything after the date and folio)
        description = line.gsub(/\d{2}-[A-Z]{3}-\d{4}\s+\d+\s*/, "").strip
        description = description.gsub(/\[.*?\]/, "").strip # Remove PII markers
        description = description.gsub(/⟪.*?⟫/, "").strip # Remove PII markers

        next if description.empty?

        # Check if this description contains amounts (like "RETIRO MIS METAS 60.00 742.61")
        amounts_in_description = description.scan(/\b[\d,]+\.\d{2}\b/)

        if amounts_in_description.length >= 2
          # This description has amounts embedded - extract them
          amount = amounts_in_description[0]
          balance = amounts_in_description[1]
          clean_description = description.gsub(/\s+\d{1,3}(?:,\d{3})*\.\d{2}\s+\d{1,3}(?:,\d{3})*\.\d{2}$/, "").strip

          descriptions << {
            date: date,
            description: clean_description,
            original_line: line,
            embedded_amount: amount,
            embedded_balance: balance
          }
        else
          descriptions << {
            date: date,
            description: description,
            original_line: line
          }
        end
      end
    end

    descriptions
  end

  def extract_amounts_and_balances(table_section)
    amounts = []

    # Method 1: Look for amounts in the DEPOSITO/RETIRO section
    if table_section.include?("DEPOSITO") && table_section.include?("RETIRO")
      deposito_section = table_section[table_section.index("DEPOSITO")..table_section.index("RETIRO") + 1000]

      # Extract all decimal amounts
      decimal_amounts = deposito_section.scan(/\b[\d,]+\.\d{2}\b/)

      # Group amounts in pairs (amount, balance)
      decimal_amounts.each_slice(2) do |pair|
        if pair.length == 2
          amounts << {
            amount: pair[0],
            balance: pair[1]
          }
        end
      end
    end

    # Method 2: Look for amounts in any table format
    table_section.lines.each do |line|
      line = line.strip
      next if line.empty?

      # Look for lines with amounts
      if line.match?(/\b[\d,]+\.\d{2}\b/)
        amount_matches = line.scan(/\b[\d,]+\.\d{2}\b/)

        # If this line has multiple amounts, treat them as amount/balance pairs
        if amount_matches.length >= 2
          amount_matches.each_slice(2) do |pair|
            if pair.length == 2
              amounts << {
                amount: pair[0],
                balance: pair[1]
              }
            end
          end
        elsif amount_matches.length == 1
          # Single amount - use it as both amount and balance
          amounts << {
            amount: amount_matches[0],
            balance: amount_matches[0]
          }
        end
      end
    end

    # Method 3: Look for amounts in the entire text that might be related to transactions
    # This handles cases where amounts are in a completely separate section
    if amounts.empty?
      # Look for patterns like "20.00 8,788.51" (amount balance)
      amount_balance_pairs = table_section.scan(/(\d{1,3}(?:,\d{3})*\.\d{2})\s+(\d{1,3}(?:,\d{3})*\.\d{2})/)
      amount_balance_pairs.each do |amount, balance|
        amounts << {
          amount: amount,
          balance: balance
        }
      end
    end

    amounts
  end

  def match_transactions(descriptions, amounts)
    transactions = []

    descriptions.each_with_index do |desc, index|
      # Check if this description has embedded amounts
      if desc[:embedded_amount] && desc[:embedded_balance]
        # Use the embedded amounts
        amount_value = desc[:embedded_amount].gsub(",", "").to_f

        transactions << {
          date: format_date(desc[:date]),
          description: desc[:description],
          amount: desc[:embedded_amount],
          balance: desc[:embedded_balance],
          transaction_type: determine_transaction_type(desc[:description]),
          bank_entry_type: amount_value > 0 ? "credit" : "debit"
        }
      else
        # Try to match with external amounts
        amount_data = amounts[index]

        if amount_data
          amount_value = amount_data[:amount].gsub(",", "").to_f

          transactions << {
            date: format_date(desc[:date]),
            description: desc[:description],
            amount: amount_data[:amount],
            balance: amount_data[:balance],
            transaction_type: determine_transaction_type(desc[:description]),
            bank_entry_type: amount_value > 0 ? "credit" : "debit"
          }
        end
      end
    end

    transactions
  end

  def determine_transaction_type(description)
    case description.upcase
    when /AHORRO MIS METAS/
      "variable_expense"
    when /SPEI.*ENVIADO/, /PAGO.*TARJETA/, /CARGO/
      "variable_expense"
    when /SPEI.*RECIBIDO/, /ABONO/
      "income"
    else
      "variable_expense"
    end
  end

  def format_date(date_str)
    # Convert DD-MMM-YYYY to YYYY-MM-DD
    day, month, year = date_str.split("-")

    # Handle Spanish month names
    month_map = {
      "ENE" => 1, "FEB" => 2, "MAR" => 3, "ABR" => 4, "MAY" => 5, "JUN" => 6,
      "JUL" => 7, "AGO" => 8, "SEP" => 9, "OCT" => 10, "NOV" => 11, "DIC" => 12
    }

    month_num = month_map[month.upcase] || 1
    "#{year}-#{month_num.to_s.rjust(2, '0')}-#{day.rjust(2, '0')}"
  rescue
    date_str
  end
end
