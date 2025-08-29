# app/services/text_extractor.rb
require "pdf/reader"
require "combine_pdf"

class TextExtractor
  # More flexible date patterns to handle various formats
  DATE_PATTERNS = [
    /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/,           # DD/MM/YYYY or DD-MM-YYYY
    /\b\d{4}[\/\-]\d{2}[\/\-]\d{2}\b/,           # YYYY/MM/DD or YYYY-MM-DD
    /\b\d{1,2}\s+(?:de\s+)?(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+(?:de\s+)?\d{4}\b/i,  # Spanish dates
    /\b(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+\d{1,2},?\s+\d{4}\b/i,  # Month DD, YYYY
    /\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/,             # DD/MM/YY or DD/MM/YYYY
    /\b\d{1,2}-\d{1,2}-\d{2,4}\b/                 # DD-MM-YY or DD-MM-YYYY
  ]

  # Financial data patterns that indicate a valid bank statement
  FINANCIAL_PATTERNS = [
    /\b(?:saldo|balance|total|amount|monto|importe)\s*:?\s*[\$€£]?\s*[\d,]+\.?\d*\b/i,  # Balance/amount patterns
    /\b(?:cuenta|account|número|number)\s*:?\s*\d+\b/i,  # Account number patterns
    /\b(?:fecha|date|periodo|period)\s*:?\s*\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b/i,  # Date with label
    /\b(?:transacción|transaction|movimiento|movement)\b/i,  # Transaction keywords
    /\b(?:depósito|deposit|retiro|withdrawal|transferencia|transfer)\b/i,  # Transaction types
    /\b[\$€£]?\s*[\d,]+\.?\d*\b/  # Currency amounts
  ]

  def self.extract_text_layer(path)
    text = +""
    begin
      PDF::Reader.open(path) { |r| r.pages.each { |p| text << "\n" << p.text.to_s } }
      if text.strip.length > 0
        return text
      end
    rescue
      # PDF::Reader failed, try CombinePDF
    end

    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      if text2.strip.length > 0
        return text2
      end
    rescue
      # CombinePDF failed
    end

    # No text extracted from PDF
    ""
  end

  def self.valid_text?(text)
    t = text.to_s.strip

    if t.empty?
      return false
    end

    # Check if any date pattern matches
    date_found = DATE_PATTERNS.any? { |pattern| pattern.match?(t) }

    # Check if any financial pattern matches
    financial_found = FINANCIAL_PATTERNS.any? { |pattern| pattern.match?(t) }

    # Text is valid if it has either dates or financial data
    date_found || financial_found
  end
end
