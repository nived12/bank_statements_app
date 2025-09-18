# app/services/ai/concerns/text_analysis.rb
module Ai
  module Concerns
    module TextAnalysis
      def parsed_transactions?(raw_text)
        # Check if the input looks like already parsed transactions
        # vs raw statement text that needs parsing
        lines = raw_text.split("\n")

        # Look for transaction-like patterns in descriptions
        transaction_lines = lines.count do |line|
          line = line.strip
          next false if line.empty?

          # More inclusive patterns to catch various transaction types
          transaction_line?(line)
        end

        # If more than 30% of lines look like transaction descriptions, this is likely parsed data
        # Lowered threshold to be more inclusive and let AI handle edge cases
        result = transaction_lines.to_f / lines.length > 0.3
        success(result)
      rescue => e
        errors.add(:base, "Failed to analyze text: #{e.message}")
        failure
      end

      def extract_keywords_inline(text)
        # INLINE METHOD: Process text directly without calling external method
        lines = text.split("\n")
        result_lines = []

        lines.each do |line|
          line = line.strip
          next if line.empty?

          # Extract key information from each line
          if transaction_line?(line)
            # Extract essential transaction information
            essential_info = extract_essential_transaction_info(line)
            result_lines << essential_info if essential_info
          end
        end

        result = result_lines.join("\n")
        success(result)
      rescue => e
        errors.add(:base, "Failed to extract keywords: #{e.message}")
        failure
      end

      private

      def transaction_line?(line)
        # More inclusive patterns to catch various transaction types
        # Date patterns (various formats)
        date_patterns = [
          /\d{1,2}\/\d{1,2}\/\d{2,4}/,  # MM/DD/YYYY or DD/MM/YYYY
          /\d{4}-\d{2}-\d{2}/,          # YYYY-MM-DD
          /\d{1,2}-\d{1,2}-\d{2,4}/     # MM-DD-YYYY or DD-MM-YYYY
        ]

        # Amount patterns (various formats)
        amount_patterns = [
          /-?\$?\d{1,3}(,\d{3})*(\.\d{2})?/,  # $1,234.56 or -1234.56
          /-?\d+\.\d{2}/,                      # 123.45 or -123.45
          /-?\d+,\d{2}/                        # 123,45 or -123,45
        ]

        # Banking keywords
        banking_keywords = [
          /SPEI/i, /RETIRO/i, /DEPOSITO/i, /PAGO/i, /TRANSFERENCIA/i,
          /NOMINA/i, /BONO/i, /RECIBIDO/i, /ENVIADO/i, /INTERBANCARIO/i,
          /TARJETA/i, /ATM/i, /COMISION/i, /INTERES/i, /SALDO/i
        ]

        # General company/merchant patterns
        company_patterns = [
          /\b[A-Z]{2,}\s+[A-Z0-9\s]+\b/,  # ALL CAPS company names
          /\b(SUPER|STORE|MARKET|SHOP|RESTAURANT|HOTEL|GAS|STATION|CENTER|MALL|PLAZA)\b/i,
          /\b(CAFE|RESTAURANT|TIENDA|FARMACIA|GASOLINERA|BANCO|BANCO)\b/i,
          /\b(AMAZON|NETFLIX|SPOTIFY|GOOGLE|APPLE|MICROSOFT)\b/i,
          /\b(CFE|TELMEX|PEMEX|WALMART|SORIANA|OXXO|7-ELEVEN)\b/i
        ]

        # Check if line contains any of these patterns
        has_date = date_patterns.any? { |pattern| line.match?(pattern) }
        has_amount = amount_patterns.any? { |pattern| line.match?(pattern) }
        has_banking_keyword = banking_keywords.any? { |pattern| line.match?(pattern) }
        has_company_pattern = company_patterns.any? { |pattern| line.match?(pattern) }

        # Exclude lines that look like headers, totals, or summaries
        exclude_patterns = [
          /total/i, /balance/i, /summary/i, /period/i, /statement/i,
          /account/i, /header/i, /information/i
        ]
        should_exclude = exclude_patterns.any? { |pattern| line.match?(pattern) }

        # A line is considered a transaction if:
        # 1. It has a date AND amount, OR
        # 2. It has a banking keyword AND amount, OR
        # 3. It has a company pattern AND amount
        # AND it's not a header/total line
        !should_exclude && (
          (has_date && has_amount) ||
          (has_banking_keyword && has_amount) ||
          (has_company_pattern && has_amount)
        )
      end

      def extract_essential_transaction_info(line)
        # Extract the most important information from a transaction line
        # This is a simplified version that focuses on key elements
        parts = line.split(/\s+/)

        # Look for amount (usually at the end)
        amount_match = line.match(/-?\$?\d{1,3}(,\d{3})*(\.\d{2})?$/)
        amount = amount_match ? amount_match[0] : nil

        # Look for date (usually at the beginning)
        date_match = line.match(/\d{1,2}\/\d{1,2}\/\d{2,4}/)
        date = date_match ? date_match[0] : nil

        # The rest is the description
        description = line.gsub(/\d{1,2}\/\d{1,2}\/\d{2,4}\s*/, "")
                        .gsub(/-?\$?\d{1,3}(,\d{3})*(\.\d{2})?$/, "")
                        .strip

        # Only return if we have meaningful content
        if description.length > 3
          "#{description} #{amount}".strip
        else
          line
        end
      end
    end
  end
end
