# frozen_string_literal: true

require "rails_helper"

RSpec.describe FileHandling do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include FileHandling
    end
  end

  let(:test_instance) { test_class.new }
  let(:statement) { double("Statement") }
  let(:file_double) { double("File") }

  before do
    allow(statement).to receive(:file).and_return(file_double)
    allow(file_double).to receive(:download).and_return("PDF content")
    allow(Rails.logger).to receive(:error)
  end

  describe "#create_temp_file" do
    it "creates a temporary file with PDF content" do
      allow(Tempfile).to receive(:new).with(["statement", ".pdf"], binmode: true).and_return(file_double)
      allow(file_double).to receive(:write).with("PDF content")
      allow(file_double).to receive(:rewind)

      result = test_instance.send(:create_temp_file, statement)

      expect(result).to eq(file_double)
      expect(file_double).to have_received(:write).with("PDF content")
      expect(file_double).to have_received(:rewind)
    end

    it "sets correct file options" do
      temp_file = double("TempFile")
      allow(Tempfile).to receive(:new).with(["statement", ".pdf"], binmode: true).and_return(temp_file)
      allow(temp_file).to receive(:write)
      allow(temp_file).to receive(:rewind)

      test_instance.send(:create_temp_file, statement)

      expect(Tempfile).to have_received(:new).with(["statement", ".pdf"], binmode: true)
    end
  end

  describe "#cleanup_temp_file" do
    it "closes and deletes the temp file" do
      allow(file_double).to receive(:close!)

      test_instance.send(:cleanup_temp_file, file_double)

      expect(file_double).to have_received(:close!)
    end

    it "handles nil file gracefully" do
      expect { test_instance.send(:cleanup_temp_file, nil) }.not_to raise_error
    end

    it "logs error when cleanup fails" do
      error = StandardError.new("Cleanup failed")
      allow(file_double).to receive(:close!).and_raise(error)

      test_instance.send(:cleanup_temp_file, file_double)

      expect(Rails.logger).to have_received(:error).with("Failed to cleanup temp file: Cleanup failed")
    end
  end
end
