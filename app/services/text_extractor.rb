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
        Rails.logger.info("TextExtractor: PDF::Reader extracted #{text.length} characters")
        Rails.logger.debug("TextExtractor: First 200 chars: #{text[0..200]}")
        return text
      end
    rescue => e
      Rails.logger.warn("TextExtractor PDF::Reader failed: #{e.message}")
    end
    
    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      if text2.strip.length > 0
        Rails.logger.info("TextExtractor: CombinePDF extracted #{text2.length} characters")
        Rails.logger.debug("TextExtractor: First 200 chars: #{text2[0..200]}")
        return text2
      end
    rescue => e
      Rails.logger.warn("TextExtractor CombinePDF failed: #{e.message}")
    end
    
    Rails.logger.warn("TextExtractor: No text extracted from PDF")
    ""
  end

  def self.valid_text?(text)
    t = text.to_s.strip
    
    if t.blank?
      Rails.logger.debug("TextExtractor: Text is blank")
      return false
    end
    
    # Check if any date pattern matches
    date_found = DATE_PATTERNS.any? { |pattern| pattern.match?(t) }
    
    # Check if any financial pattern matches
    financial_found = FINANCIAL_PATTERNS.any? { |pattern| pattern.match?(t) }
    
    # Text is valid if it has either dates or financial data
    is_valid = date_found || financial_found
    
    if is_valid
      Rails.logger.info("TextExtractor: Valid text found (#{t.length} chars)")
      Rails.logger.info("TextExtractor: Date pattern: #{date_found ? 'Yes' : 'No'}, Financial pattern: #{financial_found ? 'Yes' : 'No'}")
      Rails.logger.debug("TextExtractor: Sample text: #{t[0..100]}...")
    else
      Rails.logger.warn("TextExtractor: No valid patterns found in extracted text")
      Rails.logger.debug("TextExtractor: Text sample: #{t[0..200]}...")
    end
    
    is_valid
  end

  # Debug method to help troubleshoot extraction issues
  def self.debug_extraction(path)
    Rails.logger.info("TextExtractor: Debugging extraction for #{path}")
    
    # Try PDF::Reader
    begin
      text1 = +""
      PDF::Reader.open(path) { |r| r.pages.each { |p| text1 << "\n" << p.text.to_s } }
      Rails.logger.info("TextExtractor: PDF::Reader result - Length: #{text1.length}, Valid: #{valid_text?(text1)}")
      Rails.logger.debug("TextExtractor: PDF::Reader sample: #{text1[0..300]}...")
    rescue => e
      Rails.logger.error("TextExtractor: PDF::Reader failed: #{e.message}")
    end
    
    # Try CombinePDF
    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      Rails.logger.info("TextExtractor: CombinePDF result - Length: #{text2.length}, Valid: #{valid_text?(text2)}")
      Rails.logger.debug("TextExtractor: CombinePDF sample: #{text2[0..300]}...")
    rescue => e
      Rails.logger.error("TextExtractor: CombinePDF failed: #{e.message}")
    end
  end
end
