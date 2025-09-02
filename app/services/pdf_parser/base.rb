# app/services/pdf_parser/base.rb
require "bigdecimal"
require "date"

module PdfParser
  class Base < ApplicationService
    def initialize(text)
      super()
      @text = text
    end

    def call
      result = parse(@text)
      if result && result.is_a?(Hash)
        success(result)
      else
        errors.add(:base, :parsing_failed, message: "Failed to parse PDF content")
        failure
      end
    rescue => e
      errors.add(:base, :parsing_error, message: e.message)
      failure
    end

    private

    def parse(_text)
      raise NotImplementedError
    end

    protected

    def parse_decimal(str)
      s = str.to_s.strip
      return nil if s.empty?

      negative = false
      if s.start_with?("(") && s.end_with?(")")
        negative = true
        s = s[1..-2]
      end
      s = s.delete(" ")

      normalized =
        if s.count(",") >= 1 && s.count(".") >= 1
          s.tr(",", "")
        elsif s.count(",") >= 1 && s.count(".") == 0
          s.tr(",", ".")
        else
          s
        end

      bd = BigDecimal(normalized)
      negative ? -bd : bd
    rescue
      nil
    end

    def normalize_date_ddmmyyyy(str)
      if str =~ /\A(\d{2})[\/\-](\d{2})[\/\-](\d{4})\z/
        "#{Regexp.last_match(3)}-#{Regexp.last_match(2)}-#{Regexp.last_match(1)}"
      else
        str
      end
    rescue
      str
    end
  end
end
