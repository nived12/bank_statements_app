# app/services/pdf_parser/concerns/common_parsing_patterns.rb
module PdfParser
  module Concerns
    module CommonParsingPatterns
      extend ActiveSupport::Concern

      private

      def parse(text)
        lines = split_into_lines(text)

        result = {
          "transactions" => [],
          "financial_summaries" => [],
          "extraction_source" => extraction_source
        }

        # Extract financial summary
        financial_summary = extract_financial_summary(lines)
        result["financial_summaries"] << financial_summary if financial_summary

        # Extract transactions
        transactions = extract_transactions(lines)
        result["transactions"] = transactions if transactions.any?

        result
      end

      def extract_financial_summary(lines)
        # Override in specific parsers
        nil
      end

      def extract_transactions(lines)
        # Override in specific parsers
        []
      end

      def extraction_source
        # Override in specific parsers
        "generic_parser"
      end

      def find_transaction_table_start(lines)
        # Override in specific parsers
        nil
      end

      def is_transaction_line?(line)
        # Override in specific parsers
        false
      end

      def parse_transaction_line(line)
        # Override in specific parsers
        create_base_transaction
      end
    end
  end
end
