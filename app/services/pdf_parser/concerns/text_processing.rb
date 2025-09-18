# app/services/pdf_parser/concerns/text_processing.rb
module PdfParser
  module Concerns
    module TextProcessing
      extend ActiveSupport::Concern

      private

      def clean_text(text)
        # Handle encoding issues by forcing UTF-8 and cleaning invalid bytes
        text.to_s.dup.force_encoding("UTF-8").scrub("?")
      end

      def split_into_lines(text)
        clean_text(text).split(/\r?\n/).map(&:strip).compact_blank
      end

      def clean_description(text)
        # Remove common bank statement patterns
        cleaned = text.dup

        # Remove PII markers
        cleaned = cleaned.gsub(/\[.*?\]/, "")
        cleaned = cleaned.gsub(/⟪.*?⟫/, "")

        # Remove extra whitespace
        cleaned = cleaned.gsub(/\s+/, " ").strip

        cleaned
      end

      def clean_ocr_text(line)
        # Clean line for OCR text issues (remove [ characters and other OCR artifacts)
        line.gsub(/\[/, "").gsub(/\]/, "").strip
      end

      def extract_amount_from_line(line)
        # Extract all amounts from the line
        amounts = line.scan(/[\d,]+\.\d{2}/)
        return if amounts.empty?

        # For lines with multiple amounts, use the last one (usually the total)
        amount_to_use = amounts.length > 1 ? amounts.last : amounts.first
        parse_decimal(amount_to_use)
      end

      def extract_number_from_line(line)
        # Extract number from lines like "Días del Periodo: 31"
        number_match = line.match(/(\d+)/)
        return unless number_match

        number_match[1].to_i
      end
    end
  end
end
