# app/services/text_extractor.rb
require "pdf/reader"
require "combine_pdf"

class TextExtractor
  DATE_RX = /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b/

  def self.extract_text_layer(path)
    text = +""
    begin
      PDF::Reader.open(path) { |r| r.pages.each { |p| text << "\n" << p.text.to_s } }
      return text if text.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor PDF::Reader failed: #{e.message}")
    end
    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      return text2 if text2.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor CombinePDF failed: #{e.message}")
    end
    ""
  end

  def self.valid_text?(text)
    t = text.to_s
    t.strip.present? && DATE_RX.match?(t)
  end
end
