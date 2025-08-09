require "pdf/reader"
require "combine_pdf"

class TextExtractor
  DATE_RX = /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/

  def self.extract(path)
    text = extract_text_layer(path)
    return text if valid_text?(text)

    if ocr_enabled?
      Rails.logger.info("TextExtractor: falling back to OCR because text layer was empty or invalid")
      ocr_text = Ocr::Service.extract_text(path)
      return ocr_text if valid_text?(ocr_text)
    end

    ""
  end

  def self.extract_text_layer(path)
    # Try PDF::Reader
    begin
      text = +""
      PDF::Reader.open(path) { |r| r.pages.each { |p| text << "\n" << p.text.to_s } }
      return text if text.to_s.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor PDF::Reader failed: #{e.message}")
    end

    # Fallback: CombinePDF
    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      return text2 if text2.to_s.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor CombinePDF failed: #{e.message}")
    end

    ""
  end

  def self.valid_text?(text)
    t = text.to_s
    return false if t.strip.empty?
    # Consider text valid only if it looks like it contains transactions
    # (date pattern present). Adjust if your statements differ.
    DATE_RX.match?(t)
  end

  def self.ocr_enabled?
    ENV.fetch("OCR_ENABLED", "true") != "false"
  end
end
