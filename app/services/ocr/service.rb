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
        # Rasterize PDF to images in temp directory using modern ImageMagick command
        output_pattern = File.join(dir, "page-%02d.png")
        cmd = [ "magick", "-density", dpi.to_s, pdf_path, "-colorspace", "Gray", "-alpha", "remove", "-strip", "-filter", "Triangle", "-resize", "200%", "png:#{output_pattern}" ]

        Rails.logger.info("OCR: Converting PDF to images with command: #{cmd.join(' ')}")

        success = system(*cmd)
        unless success
          Rails.logger.warn("OCR: Modern 'magick' command failed, trying legacy 'convert' command")
          # Fallback to legacy convert command
          cmd = [ "convert", "-density", dpi.to_s, pdf_path, "-colorspace", "Gray", "-alpha", "remove", "-strip", "-filter", "Triangle", "-resize", "200%", "png:#{output_pattern}" ]
          success = system(*cmd)

          unless success
            Rails.logger.error("OCR: Both modern and legacy ImageMagick commands failed. Exit code: #{$?.exitstatus}")
            return ""
          end
        end

        # Process each image directly
        image_files = Dir.glob(File.join(dir, "page-*.png")).sort
        Rails.logger.info("OCR: Found #{image_files.count} image files to process")

        image_files.each do |img_path|
          begin
            t = RTesseract.new(img_path, lang: lang)
            text << "\n" << t.to_s
            Rails.logger.debug("OCR: Successfully processed #{File.basename(img_path)}")
          rescue => e
            Rails.logger.error("OCR processing failed for #{img_path}: #{e.message}")
          end
        end

        Rails.logger.info("OCR: Completed processing #{image_files.count} pages, extracted #{text.length} characters")
      end
    rescue => e
      Rails.logger.error("OCR failed: #{e.message}")
      Rails.logger.error("OCR backtrace: #{e.backtrace.first(3).join("\n")}")
      ""
    end
  end
end
