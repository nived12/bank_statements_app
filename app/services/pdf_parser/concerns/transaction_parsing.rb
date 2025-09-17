# app/services/pdf_parser/concerns/transaction_parsing.rb
module PdfParser
  module Concerns
    module TransactionParsing
      extend ActiveSupport::Concern

      private

      def create_base_transaction
        {
          "date" => nil,
          "description" => "",
          "reference" => "",
          "amount" => nil,
          "transaction_type" => nil,
          "bank_entry_type" => nil
        }
      end

      def enhance_transaction_with_additional_info(transaction, line)
        # Add additional description or reference information
        return transaction unless line.strip.present? && !line.match?(/\b[\d,]+\.\d{2}\b/)

        # Skip bank statement headers and formatting
        return transaction if is_bank_statement_header?(line)

        # Check if this line looks like it's starting a new section
        return transaction if is_section_break?(line)

        # Clean the line
        clean_line = clean_description(line.strip)

        # Skip if the cleaned line is empty
        return transaction if clean_line.blank?

        # Add the cleaned line to description
        if clean_line.present?
          if transaction["description"].present?
            transaction["description"] += " #{clean_line}"
          else
            transaction["description"] = clean_line
          end
        end

        transaction
      end

      def is_bank_statement_header?(line)
        # Override in specific parsers for bank-specific headers
        false
      end

      def is_section_break?(line)
        # Override in specific parsers for bank-specific section breaks
        false
      end

      def extract_reference_from_text(text)
        # Look for various reference patterns
        reference_patterns = [
          /(⟪PII:[^:]+:\d+⟫)/,    # PII tokens (check first)
          /\b([A-Z]{3,4}\d+)\b/,  # NOM001, SPEI002, etc.
          /(\d{7,})/,             # Long numeric references (7+ digits)
          /\b([A-Z0-9]{15,})\b/   # Long alphanumeric references (15+ chars)
        ]

        # Find the first reference in the text
        reference_patterns.each do |pattern|
          match = text.match(pattern)
          return match[1] || match[2] if match
        end

        nil
      end

      def remove_references_from_text(text)
        # Remove non-PII reference patterns from text, but preserve PII tokens in descriptions
        text.gsub(/\b[A-Z]{3,4}\d+\b|\d{7,}|\b[A-Z0-9]{15,}\b/, "").strip
      end
    end
  end
end
