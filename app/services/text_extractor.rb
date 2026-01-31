# app/services/text_extractor.rb
require "pdf/reader"
require "combine_pdf"

class TextExtractor
  # Custom error for password-protected PDFs
  class PasswordRequiredError < StandardError
    def initialize(msg = "PDF is password protected")
      super
    end
  end

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

  # Extract text from PDF with optional password support
  # @param path [String] Path to the PDF file
  # @param password [String, nil] Optional password to unlock the PDF
  # @return [String] Extracted text
  # @raise [PasswordRequiredError] If PDF is encrypted and no/wrong password provided
  def self.extract_text_layer(path, password: nil)
    text = +""
    password_error_detected = false

    begin
      # PDF::Reader supports password via :password option
      reader_options = password.present? ? { password: password } : {}
      PDF::Reader.open(path, reader_options) { |r| r.pages.each { |p| text << "\n" << p.text.to_s } }
      if text.strip.length > 0
        return text
      end
    rescue PDF::Reader::EncryptedPDFError => e
      # PDF is encrypted and password is missing or incorrect
      password_error_detected = true
      Rails.logger.info("PDF::Reader encryption error: #{e.message}")
    rescue StandardError => e
      # Check if error message indicates encryption
      if e.message.to_s.downcase.include?("encrypt") || e.message.to_s.downcase.include?("password")
        password_error_detected = true
      end
      Rails.logger.debug("PDF::Reader failed: #{e.message}")
    end

    begin
      # CombinePDF has limited password support
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      if text2.strip.length > 0
        return text2
      end
    rescue StandardError => e
      # Check if error message indicates encryption
      if e.message.to_s.downcase.include?("encrypt") || e.message.to_s.downcase.include?("password")
        password_error_detected = true
      end
      Rails.logger.debug("CombinePDF failed: #{e.message}")
    end

    # If we detected a password error, raise specific exception
    if password_error_detected
      raise PasswordRequiredError, "PDF is password protected. Please provide the correct password."
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
