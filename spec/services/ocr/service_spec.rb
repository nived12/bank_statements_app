require "rails_helper"

RSpec.describe Ocr::Service do
  let(:pdf_path) { Rails.root.join("spec/fixtures/files/sample_scanned.pdf").to_s }

  it "returns text when OCR succeeds" do
    allow(described_class).to receive(:rasterize).and_return(["/tmp/fake1.png", "/tmp/fake2.png"])

    fake1 = instance_double(RTesseract, to_s: "03/01/2025 Pago Nomina EMPRESA SA 15,000.00")
    fake2 = instance_double(RTesseract, to_s: "05/01/2025 Amazon Marketplace -1,299.99")

    # Stub RTesseract.new to return fakes in order
    call_count = 0
    allow(RTesseract).to receive(:new) do |_path, lang:|
      call_count += 1
      call_count == 1 ? fake1 : fake2
    end

    # Stub file deletion since paths are fake
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:delete).and_return(true)

    text = described_class.extract_text(pdf_path)
    expect(text).to include("Pago Nomina")
    expect(text).to include("Amazon Marketplace")
  end
end
