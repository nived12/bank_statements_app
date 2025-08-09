require "mini_magick"
require "rtesseract"
require "securerandom"
require "tmpdir"
require "fileutils"

module Ocr
  class Service
    def self.extract_text(pdf_path, lang: ENV.fetch("OCR_LANG", "eng+spa"), dpi: ENV.fetch("OCR_DPI", "300").to_i)
      imgs = rasterize(pdf_path, dpi: dpi)
      return "" if imgs.empty?

      text = +""
      imgs.each do |img_path|
        begin
          t = RTesseract.new(img_path, lang: lang)
          text << "\n" << t.to_s
        ensure
          File.delete(img_path) if File.exist?(img_path) && !debug_images?
        end
      end
      text
    rescue => e
      Rails.logger.error("OCR failed: #{e.message}")
      ""
    end

    def self.rasterize(pdf_path, dpi: 300)
      out_paths = []
      Dir.mktmpdir do |dir|
        # Use ImageMagick to rasterize pages at high DPI, grayscale, de-noised
        # convert -density 300 input.pdf -colorspace Gray -alpha remove -filter Triangle -resize 200% -threshold 55% page-%02d.png
        cmd = [
          "convert",
          "-density", dpi.to_s,
          pdf_path,
          "-colorspace", "Gray",
          "-alpha", "remove",
          "-strip",
          "-filter", "Triangle",
          "-resize", "200%",
          "png:#{File.join(dir, 'page-%02d.png')}"
        ]
        system(*cmd)

        Dir.glob(File.join(dir, "page-*.png")).sort.each do |p|
          dst = if debug_images?
            File.join(Dir.pwd, "ocr_debug_#{File.basename(p)}")
          else
            File.join(Dir.tmpdir, "#{SecureRandom.hex}-#{File.basename(p)}")
          end
          FileUtils.cp(p, dst)
          out_paths << dst
        end
      end
      out_paths
    rescue => e
      Rails.logger.error("Rasterize failed: #{e.message}")
      out_paths.each { |p| File.delete(p) rescue nil }
      []
    end

    def self.debug_images?
      ENV.fetch("OCR_DEBUG", "0") == "1"
    end
  end
end
