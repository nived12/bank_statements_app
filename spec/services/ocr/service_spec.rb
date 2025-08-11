require "rails_helper"

RSpec.describe Ocr::Service do
  let(:pdf_path) { Rails.root.join("spec/fixtures/files/sample_scanned.pdf").to_s }

  it "has the correct class structure" do
    expect(described_class).to respond_to(:extract_text)
    expect(described_class.method(:extract_text)).to be_a(Method)
  end

  it "handles system command failures gracefully" do
    # Simulate ImageMagick convert failure
    allow(described_class).to receive(:system).and_return(false)

    text = described_class.extract_text(pdf_path)
    expect(text).to eq("")
  end

  it "handles general errors gracefully" do
    # Simulate any other error
    allow(described_class).to receive(:system).and_raise(StandardError.new("Test error"))

    text = described_class.extract_text(pdf_path)
    expect(text).to eq("")
  end
end
