# app/services/ocr/service.rb
require "mini_magick"
require "rtesseract"
require "securerandom"
require "tmpdir"
require "fileutils"

module Ocr
  class Service
    def self.extract_text(pdf_path, lang: ENV.fetch("OCR_LANG", "eng+spa"), dpi: ENV.fetch("OCR_DPI", "300").to_i)
      text = +""

      Dir.mktmpdir do |dir|
        # Rasterize PDF to images in temp directory
        system("convert", "-density", dpi.to_s, pdf_path, "-colorspace", "Gray", "-alpha", "remove", "-strip", "-filter", "Triangle", "-resize", "200%", "png:#{File.join(dir, 'page-%02d.png')}")

        # Process each image directly
        Dir.glob(File.join(dir, "page-*.png")).sort.each do |img_path|
          begin
            t = RTesseract.new(img_path, lang: lang)
            text << "\n" << t.to_s
          rescue => e
            Rails.logger.error("OCR processing failed for #{img_path}: #{e.message}")
          end
        end
      end

      text
    rescue => e
      Rails.logger.error("OCR failed: #{e.message}")
      ""
    end
  end
end
