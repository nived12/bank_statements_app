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

  before do
    # Enable AI path
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")

    # Provide a valid text layer (no OCR)
    allow(TextExtractor).to receive(:extract_text_layer).and_return("03/01/2025 Pago Nomina EMPRESA SA 15,000.00")

    # Stub AI client
    fake_client = instance_double(Ai::Client)
    allow(Ai::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:chat).and_return(<<~JSON)
      {
        "opening_balance": 12000.0,
        "closing_balance": 13000.0,
        "transactions": [
          {
            "date": "2025-01-03",
            "description": "Pago Nomina EMPRESA SA",
            "amount": 15000.0,
            "transaction_type": "income",
            "bank_entry_type": "credit",
            "merchant": null,
            "reference": null,
            "category": "Uncategorized",
            "sub_category": null,
            "raw_text": "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
            "confidence": 0.9
          }
        ]
      }
    JSON
  end

  it "stores AI parsed JSON with transaction_type and bank_entry_type" do
    described_class.perform_now(statement_file.id)
    statement_file.reload

    expect(statement_file.status).to eq("parsed")
    tx = statement_file.parsed_json["transactions"].first
    expect(tx["transaction_type"]).to eq("income")
    expect(tx["bank_entry_type"]).to eq("credit")
    expect(tx["amount"]).to eq(15000.0)
    expect(statement_file.parsed_json["extraction_source"]).to eq("text")
  end
end
