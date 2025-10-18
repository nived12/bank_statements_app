# app/services/pdf_parser/concerns/date_parsing.rb
module PdfParser
  module Concerns
    module DateParsing
      extend ActiveSupport::Concern

      private

      def parse_spanish_date(date_str)
        # Parse dates in format like "11-AGO-2025" or "03/JUL"
        # Handle OCR errors like "11-AG0-2025" (O vs 0)
        if date_str.match(/(\d{2})-([A-Z0-9]{3})-(\d{4})/)
          # Format: DD-MMM-YYYY (with OCR error handling)
          day = Regexp.last_match(1)
          month = Regexp.last_match(2)
          year = Regexp.last_match(3)

          # Fix common OCR errors in month names
          month = fix_month_ocr_errors(month)

          return format_date_components(day, month, year)
        elsif date_str.match(/(\d{2})\/([A-Z0-9]{3})/)
          # Format: DD/MMM (year needs to be extracted from context)
          day = Regexp.last_match(1)
          month = Regexp.last_match(2)
          year = extract_year_from_statement_period

          # Fix common OCR errors in month names
          month = fix_month_ocr_errors(month)

          return format_date_components(day, month, year)
        end

        date_str
      end

      def fix_month_ocr_errors(month)
        # Fix common OCR errors in month names
        case month
        when "AG0" then "AGO"  # O vs 0
        when "JUL" then "JUL"  # Already correct
        when "JUN" then "JUN"  # Already correct
        when "MAY" then "MAY"  # Already correct
        when "ABR" then "ABR"  # Already correct
        when "MAR" then "MAR"  # Already correct
        when "FEB" then "FEB"  # Already correct
        when "ENE" then "ENE"  # Already correct
        when "DIC" then "DIC"  # Already correct
        when "NOV" then "NOV"  # Already correct
        when "OCT" then "OCT"  # Already correct
        when "SEP" then "SEP"  # Already correct
        else month  # Return as-is if not recognized
        end
      end

      def parse_ddmmyyyy_date(date_str)
        # Parse dates in format like "01/07/2025"
        if date_str.match(/(\d{2})\/(\d{2})\/(\d{4})/)
          day = Regexp.last_match(1)
          month = Regexp.last_match(2)
          year = Regexp.last_match(3)
          return "#{year}-#{month}-#{day.rjust(2, "0")}"
        end

        date_str
      end

      def extract_year_from_statement_period
        # Look for the statement period line to extract the year
        lines = @text.to_s.split(/\r?\n/).map(&:strip).compact_blank

        lines.each do |line|
          if line.include?("Periodo") && line.match(/DEL\s+\d{2}\/\d{2}\/(\d{4})/)
            return Regexp.last_match(1)
          elsif line.include?("PERIODO") && line.match(/DEL\s+(\d{2}-[A-Z]{3}-\d{4})/)
            # For Santander format
            return Regexp.last_match(1).split("-").last
          end
        end

        # Fallback to current year if period not found
        Date.current.year.to_s
      end

      private

      def format_date_components(day, month, year)
        month_map = {
          "ENE" => "01", "FEB" => "02", "MAR" => "03", "ABR" => "04",
          "MAY" => "05", "JUN" => "06", "JUL" => "07", "AGO" => "08",
          "SEP" => "09", "OCT" => "10", "NOV" => "11", "DIC" => "12"
        }

        month_num = month_map[month]
        if month_num
          return "#{year}-#{month_num}-#{day.rjust(2, "0")}"
        end

        "#{year}-#{month}-#{day}"
      end
    end
  end
end
