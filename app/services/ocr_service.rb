# app/services/ocr_service.rb
require "mini_magick"
require "rtesseract"
require "securerandom"
require "tmpdir"
require "fileutils"

class OcrService < ApplicationService
  attr_reader :lang, :dpi, :temp_dir

  def initialize(lang: ENV.fetch("OCR_LANG", "eng+spa"), dpi: ENV.fetch("OCR_DPI", "300").to_i)
    super()
    @lang = lang
    @dpi = dpi
    @temp_dir = nil
  end

  def self.call(pdf_path)
    new.call(pdf_path)
  end

  def call(pdf_path)
    validate_pdf_path(pdf_path.to_s)
    return failure if errors.any?

    extract_text_from_pdf(pdf_path.to_s)
  rescue => e
    errors.add(:base, :ocr_failed, message: "OCR processing failed: #{e.message}")
    failure
  ensure
    cleanup_temp_directory
  end

  private

  def validate_pdf_path(pdf_path)
    return errors.add(:base, :invalid_pdf, message: "PDF path cannot be blank") if pdf_path.blank?
    return errors.add(:base, :invalid_pdf, message: "PDF file not found") unless File.exist?(pdf_path)

    # Check if it's a PDF by file extension or content type
    is_pdf_by_extension = pdf_path.downcase.end_with?(".pdf")
    is_pdf_by_content = File.open(pdf_path, "rb") { |f| f.read(4) == "%PDF" }

    unless is_pdf_by_extension || is_pdf_by_content
      errors.add(:base, :invalid_pdf, message: "File must be a PDF")
    end
  end

  def extract_text_from_pdf(pdf_path)
    create_temp_directory
    return failure if errors.any?

    convert_pdf_to_images(pdf_path)
    return failure if errors.any?

    process_images_with_ocr
  end

  def create_temp_directory
    @temp_dir = Dir.mktmpdir
  rescue => e
    errors.add(:base, :temp_directory_failed, message: "Failed to create temporary directory: #{e.message}")
  end

  def convert_pdf_to_images(pdf_path)
    output_pattern = File.join(temp_dir, "page-%02d.png")
    cmd = [
      "magick", "-density", dpi.to_s, pdf_path.to_s, "-colorspace", "Gray", "-alpha", "remove", "-strip",
      "-filter", "Triangle", "-resize", "200%", "png:#{output_pattern}"
    ]
    success = system(*cmd)

    return true if success

    errors.add(:base, :conversion_failed, message: "Failed to convert PDF to images. Ensure ImageMagick 7+ is installed.")
  end

  def process_images_with_ocr
    image_files = find_image_files
    return failure if errors.any?

    extracted_text = extract_text_from_images(image_files)
    return failure if errors.any?

    success(extracted_text)
  end

  def find_image_files
    pattern = File.join(temp_dir, "page-*.png")
    files = Dir.glob(pattern).sort

    if files.empty?
      errors.add(:base, :no_images_found, message: "No image files generated from PDF conversion")
      return []
    end

    files
  end

  def extract_text_from_images(image_files)
    text = +""
    processed_count = 0
    failed_count = 0

    image_files.each do |img_path|
      result = process_single_image(img_path)
      if result.success?
        text << "\n" << result.payload
        processed_count += 1
      else
        failed_count += 1
        add_errors_from(result)
      end
    end

    if failed_count > 0
      errors.add(:base, :partial_ocr_failure, message: "#{failed_count} out of #{image_files.count} pages failed OCR processing")
    end

    Rails.logger.info("OCR: Completed processing #{processed_count} pages, extracted #{text.length} characters")
    text
  end

  def process_single_image(img_path)
    begin
      tesseract = RTesseract.new(img_path, lang: lang)
      extracted_text = tesseract.to_s

      if extracted_text.blank?
        errors.add(:base, :no_text_extracted, message: "No text extracted from #{File.basename(img_path)}")
        return failure
      end

      success(extracted_text)
    rescue => e
      errors.add(:base, :ocr_processing_failed, message: "OCR processing failed for #{File.basename(img_path)}: #{e.message}")
      failure
    end
  end

  def cleanup_temp_directory
    return unless temp_dir && Dir.exist?(temp_dir)

    FileUtils.remove_entry(temp_dir)
  rescue => e
    Rails.logger.warn("OCR: Failed to cleanup temporary directory: #{e.message}")
  end

  # Override context_for_logging to provide additional context when logging failures
  def context_for_logging
    {
      "Language" => lang,
      "DPI" => dpi,
      "Temp directory" => temp_dir || "N/A"
    }
  end
end
