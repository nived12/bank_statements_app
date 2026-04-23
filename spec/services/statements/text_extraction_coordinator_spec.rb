require "rails_helper"

RSpec.describe Statements::TextExtractionCoordinator do
  let(:pdf_path) { Rails.root.join("spec/fixtures/files/sample.pdf").to_s }

  describe ".markitdown_enabled?" do
    it "defaults to false" do
      allow(ENV).to receive(:fetch).with("MARKITDOWN_ENABLED", false).and_return(false)

      expect(described_class.markitdown_enabled?).to be(false)
    end
  end

  describe "#call" do
    it "returns native text metadata when native extraction is valid" do
      allow(TextExtractor).to receive(:extract_text_layer).and_return("Saldo anterior: $1,234.56")
      allow(TextExtractor).to receive(:valid_text?).and_return(true)

      result = described_class.call(pdf_path: pdf_path, mode: :native_only)

      expect(result).to be_success
      expect(result.payload).to include(
        text: "Saldo anterior: $1,234.56",
        format: "plain_text",
        source: "native_pdf_text",
        usable_for_parser: true
      )
    end

    it "returns MarkItDown metadata when fallback is enabled and command succeeds" do
      allow(TextExtractor).to receive(:extract_text_layer).and_return("")
      allow(TextExtractor).to receive(:valid_text?).and_return(false, true)
      allow(ENV).to receive(:fetch).with("MARKITDOWN_ENABLED", false).and_return("true")
      allow(ENV).to receive(:fetch).with("MARKITDOWN_COMMAND", "markitdown").and_return("markitdown")
      allow(ENV).to receive(:fetch).with("MARKITDOWN_TIMEOUT_SECONDS", 45).and_return("45")
      allow(Open3).to receive(:capture3).with("markitdown", pdf_path).and_return(
        ["# Statement\n\n| Fecha | Monto |\n| --- | --- |\n", "", instance_double(Process::Status, success?: true)]
      )

      result = described_class.call(pdf_path: pdf_path, mode: :prefer_native)

      expect(result).to be_success
      expect(result.payload).to include(
        format: "markdown",
        source: "markitdown_pdf",
        usable_for_parser: false
      )
      expect(result.payload[:text]).to include("| Fecha | Monto |")
    end

    it "returns nil payload when MarkItDown command is unavailable" do
      allow(ENV).to receive(:fetch).with("MARKITDOWN_ENABLED", false).and_return("true")
      allow(ENV).to receive(:fetch).with("MARKITDOWN_COMMAND", "markitdown").and_return("markitdown")
      allow(ENV).to receive(:fetch).with("MARKITDOWN_TIMEOUT_SECONDS", 45).and_return("45")
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      result = described_class.call(pdf_path: pdf_path, mode: :markitdown_only)

      expect(result).to be_success
      expect(result.payload).to be_nil
    end
  end
end
