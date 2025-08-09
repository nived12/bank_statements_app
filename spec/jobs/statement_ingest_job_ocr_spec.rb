require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  let(:bank_account) do
    create(
      :bank_account,
      bank_name: "BBVA",
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0
    )
  end

  let(:statement_file) { create(:statement_file, bank_account: bank_account) }

  let(:ocr_text) do
    <<~TXT
      03/01/2025 Pago Nomina EMPRESA SA 15,000.00
      05/01/2025 Amazon Marketplace -1,299.99
    TXT
  end

  before do
    # Simulate text extractor failing to find text, forcing OCR path
    allow(TextExtractor).to receive(:extract).and_call_original
    allow(Ocr::Service).to receive(:extract_text).and_return(ocr_text)
  end

  it "parses transactions when OCR provides text" do
    described_class.perform_now(statement_file.id)
    statement_file.reload
    expect(statement_file.status).to eq("parsed")
    expect(statement_file.parsed_json["transactions"].size).to be >= 2
  end
end
