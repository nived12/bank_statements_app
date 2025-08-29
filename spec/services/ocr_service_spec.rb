# spec/services/ocr_service_spec.rb
require "rails_helper"

RSpec.describe OcrService do
  let(:service) { described_class.new }
  let(:valid_pdf_path) { Rails.root.join("spec", "fixtures", "files", "sample.pdf") }
  let(:invalid_pdf_path) { "/nonexistent/file.pdf" }
  let(:non_pdf_path) { Rails.root.join("spec", "fixtures", "sample.txt") }

  describe "#initialize" do
    it "sets default values from environment variables" do
      expect(service.lang).to eq("eng+spa")
      # Use the actual environment variable value instead of hardcoded 300
      expected_dpi = ENV.fetch("OCR_DPI", "300").to_i
      expect(service.dpi).to eq(expected_dpi)
    end

    it "allows custom values" do
      custom_service = described_class.new(lang: "eng", dpi: 600)
      expect(custom_service.lang).to eq("eng")
      expect(custom_service.dpi).to eq(600)
    end
  end

  describe "#call" do
    context "with valid PDF path" do
      before do
        allow(service).to receive(:create_temp_directory)
        allow(service).to receive(:convert_pdf_to_images)
        allow(service).to receive(:process_images_with_ocr).and_return(service.success("extracted text"))
      end

      it "returns success with extracted text" do
        result = service.call(valid_pdf_path)
        expect(result.success?).to be true
        expect(result.payload).to eq("extracted text")
      end
    end

    context "with invalid PDF path" do
      it "returns failure for blank path" do
        result = service.call("")
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("PDF path cannot be blank")
      end

      it "returns failure for non-existent file" do
        result = service.call(invalid_pdf_path)
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("PDF file not found")
      end

      it "returns failure for non-PDF file" do
        File.write(non_pdf_path, "test content")
        result = service.call(non_pdf_path.to_s)
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("File must be a PDF")
        File.delete(non_pdf_path)
      end
    end

    context "when OCR processing fails" do
      before do
        allow(service).to receive(:create_temp_directory)
        allow(service).to receive(:convert_pdf_to_images)
        allow(service).to receive(:process_images_with_ocr).and_raise(StandardError, "OCR failed")
      end

      it "returns failure with error message" do
        result = service.call(valid_pdf_path)
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("OCR processing failed: OCR failed")
      end
    end
  end

  describe "private methods" do
    describe "#validate_pdf_path" do
      it "adds error for blank path" do
        service.send(:validate_pdf_path, "")
        expect(service.errors[:base]).to include("PDF path cannot be blank")
      end

      it "adds error for non-existent file" do
        service.send(:validate_pdf_path, invalid_pdf_path)
        expect(service.errors[:base]).to include("PDF file not found")
      end

      it "adds error for non-PDF file" do
        File.write(non_pdf_path, "test content")
        service.send(:validate_pdf_path, non_pdf_path.to_s)
        expect(service.errors[:base]).to include("File must be a PDF")
        File.delete(non_pdf_path)
      end
    end

    describe "#convert_pdf_to_images" do
      before do
        allow(service).to receive(:temp_dir).and_return("/tmp/test")
      end

      it "returns true when conversion succeeds" do
        allow(service).to receive(:system).and_return(true)
        result = service.send(:convert_pdf_to_images, valid_pdf_path)
        expect(result).to be true
      end

      it "adds error when conversion fails" do
        allow(service).to receive(:system).and_return(false)
        result = service.send(:convert_pdf_to_images, valid_pdf_path)
        expect(service.errors[:base]).to include("Failed to convert PDF to images. Ensure ImageMagick 7+ is installed.")
      end
    end

    describe "#find_image_files" do
      before do
        allow(service).to receive(:temp_dir).and_return("/tmp/test")
      end

      it "adds error when no images found" do
        allow(Dir).to receive(:glob).and_return([])
        result = service.send(:find_image_files)
        expect(service.errors[:base]).to include("No image files generated from PDF conversion")
        expect(result).to eq([])
      end

      it "returns sorted image files" do
        allow(Dir).to receive(:glob).and_return([ "/tmp/test/page-02.png", "/tmp/test/page-01.png" ])
        result = service.send(:find_image_files)
        expect(result).to eq([ "/tmp/test/page-01.png", "/tmp/test/page-02.png" ])
      end
    end

    describe "#process_single_image" do
      let(:mock_tesseract) { instance_double(RTesseract) }

      before do
        allow(RTesseract).to receive(:new).and_return(mock_tesseract)
      end

      it "returns success with extracted text" do
        allow(mock_tesseract).to receive(:to_s).and_return("extracted text")
        result = service.send(:process_single_image, "test.png")
        expect(result.success?).to be true
        expect(result.payload).to eq("extracted text")
      end

      it "returns failure for blank text" do
        allow(mock_tesseract).to receive(:to_s).and_return("")
        result = service.send(:process_single_image, "test.png")
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("No text extracted from test.png")
      end

      it "returns failure when OCR raises error" do
        allow(mock_tesseract).to receive(:to_s).and_raise(StandardError, "OCR failed")
        result = service.send(:process_single_image, "test.png")
        expect(result.failure?).to be true
        expect(service.errors[:base]).to include("OCR processing failed for test.png: OCR failed")
      end
    end

    describe "#cleanup_temp_directory" do
      it "removes temp directory when it exists" do
        allow(service).to receive(:temp_dir).and_return("/tmp/test")
        allow(Dir).to receive(:exist?).with("/tmp/test").and_return(true)
        allow(FileUtils).to receive(:remove_entry)

        service.send(:cleanup_temp_directory)
        expect(FileUtils).to have_received(:remove_entry).with("/tmp/test")
      end

      it "handles cleanup errors gracefully" do
        allow(service).to receive(:temp_dir).and_return("/tmp/test")
        allow(Dir).to receive(:exist?).with("/tmp/test").and_return(true)
        allow(FileUtils).to receive(:remove_entry).and_raise(StandardError, "Cleanup failed")

        expect { service.send(:cleanup_temp_directory) }.not_to raise_error
      end
    end

    describe "#context_for_logging" do
      it "returns context hash" do
        context = service.send(:context_for_logging)
        expected_dpi = ENV.fetch("OCR_DPI", "300").to_i
        expect(context).to include(
          "Language" => "eng+spa",
          "DPI" => expected_dpi,
          "Temp directory" => "N/A"
        )
      end
    end
  end
end
