require "bigdecimal"
require "date"

module PdfParser
  class Base
    def parse(_text, _context: {})
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
          s.tr(",", "")              # 1,234.56 -> 1234.56
        elsif s.count(",") >= 1 && s.count(".") == 0
          s.tr(",", ".")             # 1234,56 -> 1234.56
        else
          s                          # already dot-decimal or integer
        end

      bd = BigDecimal(normalized)
      negative ? -bd : bd
    rescue
      nil
    end

    def normalize_date_ddmmyyyy(str)
      str = str.to_s.strip
      return str if str.empty?

      if str.include?("/")
        Date.strptime(str, "%d/%m/%Y").strftime("%Y-%m-%d")
      elsif str.include?("-")
        Date.strptime(str, "%d-%m-%Y").strftime("%Y-%m-%d")
      else
        str
      end
    rescue
      str
    end
  end
end
