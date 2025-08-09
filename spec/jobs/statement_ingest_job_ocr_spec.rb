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
    # Force empty/invalid text layer so OCR triggers
    allow(TextExtractor).to(receive(:extract_text_layer).and_return(""))

    # Provide OCR text
    allow(Ocr::Service).to receive(:extract_text).and_return(ocr_text)

    # Disable AI for this test (use deterministic parser)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("")
  end

  it "parses transactions when OCR provides text" do
    described_class.perform_now(statement_file.id)
    statement_file.reload

    expect(statement_file.status).to eq("parsed")
    expect(statement_file.parsed_json["extraction_source"]).to eq("ocr")

    # From deterministic parser: +15000 income, -1299.99 variable_expense
    txs = statement_file.parsed_json["transactions"]
    expect(txs.size).to be >= 2

    first = txs.first
    expect(first["transaction_type"]).to eq("income")
    expect(first["bank_entry_type"]).to eq("credit")

    second = txs[1]
    expect(second["transaction_type"]).to eq("variable_expense")
    expect(second["bank_entry_type"]).to eq("debit")

    # Importer should have created rows
    expect(Transaction.where(statement_file: statement_file).count).to be >= 2
  end
end
