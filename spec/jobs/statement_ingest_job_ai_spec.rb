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
    # Set environment variables for AI path
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    # Add default stub for any other ENV keys that might be accessed
    allow(ENV).to receive(:[]).and_call_original

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

  context "when PII redaction is enabled" do
    before do
      # Add default stub for any other ENV keys that might be accessed
      allow(ENV).to receive(:[]).and_call_original
      # Override PII_REDACTION_ENABLED specifically
      allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("1")
      # Stub the text extraction methods that are actually used in the job
      allow(TextExtractor).to receive(:extract_text_layer).and_return("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
      allow(TextExtractor).to receive(:valid_text?).and_return(true)
    end

    it "restores PII tokens from AI output before persisting" do
      # Create a mock post-processor that we can verify is called
      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)

      # Set up the mock to return the expected data
      allow(mock_processor).to receive(:call).and_return({
        "opening_balance" => 0.0,
        "closing_balance" => 0.0,
        "extraction_source" => "text",
        "raw_text" => "Payment from ⟪PII:EMAIL:1⟫ on 2025-08-01 amount 1200",
        "transactions" => [
          {
            "date" => "2025-08-01",
            "description" => "Payment from ⟪PII:EMAIL:1⟫",
            "amount" => 1200.0,
            "transaction_type" => "income",
            "bank_entry_type" => "credit",
            "category" => "Uncategorized",
            "confidence" => 1.0
          }
        ]
      })

      # Also stub the fallback parser to ensure it doesn't interfere
      allow_any_instance_of(PdfParser::Generic).to receive(:parse).and_return({
        "opening_balance" => 0.0,
        "closing_balance" => 0.0,
        "transactions" => []
      })

      described_class.perform_now(statement_file.id)
      statement_file.reload

      # Verify the AI post-processor was called with the redacted text (which contains PII tokens)
      expect(mock_processor).to have_received(:call).with(
        hash_including(
          raw_text: "Payment from ⟪PII:EMAIL:1⟫ on 2025-08-01 amount 1200"
        )
      )

      # Map & HMAC are stored
      expect(statement_file.redaction_map).to be_present
      expect(statement_file.redaction_hmac).to be_present

      # Persisted JSON has the restored email, not the token
      desc = statement_file.parsed_json.dig("transactions", 0, "description")
      expect(desc).to eq("Payment from juan.perez@example.com")
    end
  end
end
