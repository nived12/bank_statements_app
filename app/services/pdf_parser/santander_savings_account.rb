# app/services/pdf_parser/santander_savings_account.rb
module PdfParser
  class SantanderSavingsAccount < Base
    include Concerns::CommonParsingPatterns
    include Concerns::TextProcessing
    include Concerns::DateParsing
    include Concerns::FinancialSummaryExtraction
    include Concerns::TransactionClassification
    include Concerns::TransactionParsing

    # Constants for filtering non-transaction amount lines
    NON_TRANSACTION_AMOUNT_KEYWORDS = %w[
      CUENTA CLIENTE RFC CODIGO TELEFONO COLONIA ALCALDIA CIUDAD REFERENCIA PAGINA ESTADO PERIODO
      VISTA MONEDA BRUTOS NETOS COBRADAS NOMINAL REAL SANTANDER Página
    ]

    def extraction_source
      "santander_savings_parser"
    end

    private

    def extract_financial_summary(lines)
      extract_financial_summary_base(lines, "Santander")
    end

    def extract_transactions(lines)
      transactions = []

      # Look for transaction table headers
      transaction_start = find_transaction_table_start(lines)
      return [] unless transaction_start

      # Process lines sequentially and match descriptions with amounts
      current_transaction = nil

      lines.each_with_index do |line, index|
        # Skip if we reach the end of transactions
        next if line.include?("TOTAL") || line.include?("ESTADO DE CUENTA") ||
                line.match?(/^\s*Página\s+\d+\s+de\s+\d+\s*$/i)

        # Check if this line contains a transaction description
        if is_transaction_description_line?(line)
          # Save previous transaction if exists
          if current_transaction
            transactions << current_transaction
          end

          # Start new transaction
          current_transaction = parse_transaction_description_line(line)
        elsif current_transaction && line.strip.present?
          # This might be additional description or reference info
          current_transaction = enhance_transaction_with_additional_info(current_transaction, line)
        end
      end

      # Handle the last transaction
      if current_transaction
        transactions << current_transaction
      end

      # Find all transaction amount lines in the text
      amount_lines = []
      lines.each_with_index do |line, index|
        if line.match?(/^\s*[\d,]+\.\d{2}\s+[\d,]+\.\d{2}\s*$/) &&
           line.scan(/\b[\d,]+\.\d{2}\b/).count == 2
          amount_lines << { line: line, index: index }
        end
      end

      # Match transactions with amounts using a more robust approach
      # First, try to match by position for transactions that have corresponding amount lines
      used_amount_indices = Set.new

      transactions.each_with_index do |transaction, index|
        if amount_lines[index] && !used_amount_indices.include?(index)
          amounts = amount_lines[index][:line].scan(/\b[\d,]+\.\d{2}\b/)
          if amounts.any?
            transaction = match_transaction_with_amounts(transaction, [ amounts ])
            transactions[index] = transaction
            used_amount_indices.add(index)
          end
        end
      end

      # For transactions without amounts, try to find the best matching amount line
      transactions.each_with_index do |transaction, index|
        next if transaction["amount"] && transaction["amount"] != "0.0"

        # Find unused amount lines
        unused_amounts = amount_lines.reject { |amount_line| used_amount_indices.include?(amount_line[:index]) }

        if unused_amounts.any?
          # Use the closest unused amount line
          closest_amount = unused_amounts.min_by { |amount_line| (amount_line[:index] - index).abs }
          amounts = closest_amount[:line].scan(/\b[\d,]+\.\d{2}\b/)
          if amounts.any?
            transaction = match_transaction_with_amounts(transaction, [ amounts ])
            transactions[index] = transaction
            used_amount_indices.add(closest_amount[:index])
          end
        end
      end

      transactions
    end

    def find_transaction_table_start(lines)
      # Look for the first transaction line (date + folio pattern)
      # This is more reliable than looking for headers since they might be split across lines
      lines.each_with_index do |line, index|
        # Look for lines that contain date and folio (transaction descriptions)
        if line.match?(/\d{2}-[A-Z]{3}-\d{4}/) && line.match?(/\d{7}/) &&
           !line.include?("FECHA") && !line.include?("FOLIO") && !line.include?("DESCRIPCION")
          # This looks like a transaction line, start from here
          return index
        end
      end

      # Fallback: look for table headers
      lines.each_with_index do |line, index|
        # Check for Santander header pattern - look for FECHA FOLIO DESCRIPCION DEPOSITO
        if line.include?("FECHA") && line.include?("FOLIO") && line.include?("DESCRIPCION") && line.include?("DEPOSITO")
          # This is the complete header, return the line after
          return index + 1
        end

        # Also check for the pattern where headers are split across lines
        if line.include?("FECHA") && line.include?("FOLIO") && line.include?("DESCRIPCION")
          # Look for the next few lines that might contain DEPOSITO and RETIRO
          (index + 1..[ index + 5, lines.length - 1 ].min).each do |next_index|
            next_line = lines[next_index]
            if next_line.include?("DEPOSITO") && next_line.include?("RETIRO")
              # This is the complete header, return the line after
              return next_index + 1
            end
          end
        end

        # Look for lines that contain DEPOSITO and RETIRO (amount columns)
        if line.include?("DEPOSITO") && line.include?("RETIRO") && line.include?("SALDO")
          # This is the amount header, return the line after
          return index + 1
        end
      end

      nil
    end

    def is_transaction_description_line?(line)
      # Check if line contains date pattern and folio (transaction description)
      # Use more flexible date pattern to handle OCR errors (O vs 0, etc.)
      date_pattern = /\d{2}-[A-Z0-9]{3}-\d{4}/
      folio_pattern = /\d{7}/
      is_header = (line.include?("FECHA") && line.include?("FOLIO") && line.include?("DESCRIPCION")) ||
                  (line.include?("DEPOSITO") && line.include?("RETIRO") && line.include?("SALDO"))

      # Clean line for OCR text issues (remove [ characters and other OCR artifacts)
      clean_line = line.gsub(/\[/, "").gsub(/\]/, "").strip

      has_date = clean_line.match?(date_pattern)
      has_folio = clean_line.match?(folio_pattern)
      is_not_header = !is_header

      has_date && has_folio && is_not_header
    end

    def is_amount_line?(line)
      # Check if line contains only amounts (no dates or descriptions)
      amount_pattern = /\b[\d,]+\.\d{2}\b/
      date_pattern = /\d{2}-[A-Z]{3}-\d{4}/

      # Must have amounts and no dates
      has_amounts = line.match?(amount_pattern)
      has_dates = line.match?(date_pattern)

      # Must not contain text that indicates it's not a transaction amount
      # Focus on generic bank statement elements, not client-specific data
      is_not_transaction_amount = NON_TRANSACTION_AMOUNT_KEYWORDS.any? { |keyword| line.include?(keyword) }

      # Special case: lines that look like transaction amounts (e.g., "20.00 8,788.51")
      is_transaction_amount_line = line.match?(/^\s*[\d,]+\.\d{2}\s+[\d,]+\.\d{2}\s*$/) &&
                                   line.scan(amount_pattern).count == 2

      (has_amounts && !has_dates && !is_not_transaction_amount) || is_transaction_amount_line
    end

    def is_transaction_line?(line)
      # Legacy method - kept for compatibility
      is_transaction_description_line?(line)
    end

    def parse_transaction_description_line(line)
      transaction = create_base_transaction

      # Clean line for OCR text issues (remove [ characters and other OCR artifacts)
      clean_line = clean_ocr_text(line)

      # Extract date from the beginning of the line
      date_match = clean_line.match(/\A(\d{2}-[A-Z]{3}-\d{4})/)
      if date_match
        transaction["date"] = parse_spanish_date(date_match[1])
      end

      # Extract folio (reference number)
      folio_match = clean_line.match(/\d{2}-[A-Z]{3}-\d{4}\s+(\d+)/)
      if folio_match
        transaction["reference"] = folio_match[1]
      end

      # Extract description (everything after folio)
      if folio_match
        description_start = folio_match.end(1)
        transaction["description"] = clean_description(clean_line[description_start..-1].strip)
      end

      transaction
    end

    def find_best_amount_match(description, amount_lines, description_index)
      # Look for amount lines that are likely to be transaction amounts
      # Focus on lines that contain only amounts (no text)

      # Filter for lines that contain only amounts and numbers
      transaction_amount_lines = amount_lines.select do |amt|
        line = amt[:line]
        # Look for lines that contain only amounts (no text, no percentages, no account numbers)
        line.match?(/^[\d,.\s]+$/) &&
        !NON_TRANSACTION_AMOUNT_KEYWORDS.any? { |keyword| line.include?(keyword) }
      end

      # Use the amount at the same index if available
      if description_index < transaction_amount_lines.length
        return transaction_amount_lines[description_index]
      elsif transaction_amount_lines.any?
        # Use the last available amount
        return transaction_amount_lines.last
      end

      nil
    end

    # Override the shared concern to add Santander-specific withdrawal patterns
    def is_withdrawal?(description)
      super || description.include?("AHORRO MIS METAS")
    end

    def parse_transaction_line(line)
      # Legacy method - kept for compatibility
      parse_transaction_description_line(line)
    end

    # Override shared concern methods for Santander-specific behavior
    def is_bank_statement_header?(line)
      # Check for Santander-specific headers
      line.include?("FECHA") && line.include?("FOLIO") && line.include?("DESCRIPCION") ||
      line.include?("DEPOSITO") && line.include?("RETIRO") && line.include?("SALDO") ||
      line.match?(/^\s*Página\s+\d+\s+de\s+\d+\s*$/i) ||
      line.match?(/^\s*ESTADO\s+DE\s+CUENTA/i) ||
      line.match?(/^\s*BANCO\s+SANTANDER/i)
    end

    def is_section_break?(line)
      # Check for patterns that indicate we've moved beyond transaction descriptions
      line.match?(/ESTADO\s+DE\s+CUENTA/i) ||
      line.match?(/BANCO\s+SANTANDER/i) ||
      line.match?(/Página\s+\d+\s+de\s+\d+/i) ||
      line.match?(/TOTAL/i)
    end
  end
end
