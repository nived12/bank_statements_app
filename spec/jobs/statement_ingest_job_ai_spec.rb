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
    # ENV defaults
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    allow(ENV).to receive(:[]).and_call_original

    # Provide a valid text layer (no OCR)
    allow(TextExtractor).to receive(:extract_text_layer).and_return("03/01/2025 Pago Nomina EMPRESA SA 15,000.00")
    allow(TextExtractor).to receive(:valid_text?).and_return(true)

    # Stub AI client (legacy path used in this example)
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
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("1")

      # Ensure redactor sees PII to build a map
      allow(TextExtractor).to receive(:extract_text_layer)
        .and_return("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
      allow(TextExtractor).to receive(:valid_text?).and_return(true)
    end

    it "persists redaction_map and redaction_hmac after sending to AI" do
      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)
      allow(mock_processor).to receive(:call).and_return({ "transactions" => [] })

      described_class.perform_now(statement_file.id)
      statement_file.reload

      expect(statement_file.redaction_map).to be_present
      expect(statement_file.redaction_hmac).to be_present
    end

    it "restores PII tokens from AI output before persisting" do
      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)

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

      # Keep fallback parser from interfering
      allow_any_instance_of(PdfParser::Generic).to receive(:parse).and_return({
        "opening_balance" => 0.0,
        "closing_balance" => 0.0,
        "transactions" => []
      })

      described_class.perform_now(statement_file.id)
      statement_file.reload

      expect(Ai::PostProcessor).to have_received(:new)
      expect(statement_file.redaction_map).to be_present
      expect(statement_file.redaction_hmac).to be_present

      desc = statement_file.parsed_json.dig("transactions", 0, "description")
      expect(desc).to eq("Payment from juan.perez@example.com")
      expect(statement_file.parsed_json["raw_text"]).to eq("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
    end

    it "warns on HMAC mismatch but still restores tokens" do
      # 1st run populates map + valid HMAC
      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)
      tokenized = {
        "transactions" => [
          {
            "date" => "2025-08-01",
            "description" => "Payment from ⟪PII:EMAIL:1⟫",
            "amount" => 100.0,
            "transaction_type" => "income",
            "bank_entry_type" => "credit"
          }
        ]
      }
      allow(mock_processor).to receive(:call).and_return(tokenized)

      described_class.perform_now(statement_file.id)
      statement_file.reload

      # Tamper HMAC to force mismatch on verification
      statement_file.update!(redaction_hmac: "deadbeef")

      # Capture logger
      logger_double = instance_double(Logger)
      allow(Rails).to receive(:logger).and_return(logger_double)
      allow(logger_double).to receive(:warn)

      # 2nd run triggers verification and still restores
      described_class.perform_now(statement_file.id)
      statement_file.reload

      expect(logger_double).to have_received(:warn).with(/HMAC mismatch/)
      parsed = statement_file.parsed_json.is_a?(String) ? JSON.parse(statement_file.parsed_json) : statement_file.parsed_json
      expect(parsed.dig("transactions", 0, "description")).to eq("Payment from juan.perez@example.com")
    end

    it "skips restore when redaction_map is blank" do
      # Clear map/hmac explicitly
      statement_file.update!(redaction_map: nil, redaction_hmac: nil)

      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)
      allow(mock_processor).to receive(:call).and_return({
        "transactions" => [
          { "description" => "Payment from ⟪PII:EMAIL:1⟫" }
        ]
      })

      described_class.perform_now(statement_file.id)
      statement_file.reload

      parsed = statement_file.parsed_json.is_a?(String) ? JSON.parse(statement_file.parsed_json) : statement_file.parsed_json
      expect(parsed.dig("transactions", 0, "description")).to eq("Payment from ⟪PII:EMAIL:1⟫")
    end
  end

  context "when PII redaction is disabled" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return(nil)
      allow(TextExtractor).to receive(:valid_text?).and_return(true)

      # Keep AI path stable
      mock_processor = instance_double(Ai::PostProcessor)
      allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)
      allow(mock_processor).to receive(:call).and_return({ "transactions" => [] })
    end

    it "does not persist redaction_map/hmac" do
      described_class.perform_now(statement_file.id)
      statement_file.reload
      expect(statement_file.redaction_map).to be_nil.or be_empty
      expect(statement_file.redaction_hmac).to be_nil.or be_empty
    end
  end
end
