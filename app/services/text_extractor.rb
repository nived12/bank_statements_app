require "pdf/reader"
require "combine_pdf"

class TextExtractor
  def self.extract(path)
    text = +""
    begin
      PDF::Reader.open(path) { |r| r.pages.each { |p| text << "\n" << p.text.to_s } }
      return text if text.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor PDF::Reader failed: #{e.message}")
    end

    # Fallback: CombinePDF text extraction (not perfect, but helps)
    begin
      pdf = CombinePDF.load(path)
      text2 = pdf.pages.map { |p| p.text.to_s }.join("\n")
      return text2 if text2.strip.length > 0
    rescue => e
      Rails.logger.warn("TextExtractor CombinePDF failed: #{e.message}")
    end

    "" # signal failure to caller
  end
end
