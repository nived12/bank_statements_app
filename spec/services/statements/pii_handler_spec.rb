# spec/services/statements/pii_handler_spec.rb
require "rails_helper"

RSpec.describe Statements::PiiHandler do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:pii_redactor) { instance_double(PiiRedactor) }

  let(:data) do
    {
      transactions: [
        {
          "date" => "2024-01-15",
          "description" => "Transfer to John Smith CLABE:012345678901234567",
          "amount" => -100.00
        },
        {
          "date" => "2024-01-16",
          "description" => "Payment from Maria Garcia",
          "amount" => 500.00
        }
      ],
      financial_summaries: []
    }
  end

  before do
    allow(PiiRedactor).to receive(:new).and_return(pii_redactor)
  end

  describe "#call (redaction)" do
    let(:redacted_description) { "Transfer to ⟪PII:NAME:1⟫ ⟪PII:CLABE:1⟫" }
    let(:token_map) { { "⟪PII:NAME:1⟫" => "John Smith", "⟪PII:CLABE:1⟫" => "012345678901234567" } }
    let(:hmac) { "test-hmac" }

    before do
      allow(pii_redactor).to receive(:redact)
        .with("Transfer to John Smith CLABE:012345678901234567")
        .and_return([redacted_description, token_map, hmac])

      allow(pii_redactor).to receive(:redact)
        .with("Payment from Maria Garcia")
        .and_return(["Payment from ⟪PII:NAME:2⟫", { "⟪PII:NAME:2⟫" => "Maria Garcia" }, hmac])
    end

    it "redacts PII from transaction descriptions" do
      result = described_class.new(statement_file, data).call

      expect(result).to be_success
      expect(result.payload[:transactions].first["description"]).to eq(redacted_description)
    end

    it "stores redaction map on statement file" do
      described_class.new(statement_file, data).call

      expect(statement_file.reload.redaction_map).to be_present
      expect(statement_file.redaction_hmac).to eq(hmac)
    end

    it "returns data with redacted transactions" do
      result = described_class.new(statement_file, data).call

      expect(result).to be_success
      expect(result.payload[:transactions].count).to eq(2)
    end

    context "when data has no transactions" do
      let(:empty_data) { { transactions: [] } }

      it "returns data unchanged" do
        result = described_class.new(statement_file, empty_data).call

        expect(result).to be_success
        expect(result.payload).to eq(empty_data)
      end
    end
  end

  describe ".restore (restoration)" do
    let(:redacted_data) do
      {
        transactions: [
          {
            "date" => "2024-01-15",
            "description" => "Transfer to ⟪PII:NAME:1⟫ ⟪PII:CLABE:1⟫",
            "amount" => -100.00
          }
        ]
      }
    end

    let(:redaction_map) do
      {
        "⟪PII:NAME:1⟫" => "John Smith",
        "⟪PII:CLABE:1⟫" => "012345678901234567"
      }
    end

    before do
      statement_file.update(redaction_map: redaction_map)

      allow(pii_redactor).to receive(:restore)
        .with("Transfer to ⟪PII:NAME:1⟫ ⟪PII:CLABE:1⟫", redaction_map)
        .and_return("Transfer to John Smith CLABE:012345678901234567")
    end

    it "restores PII from redacted descriptions" do
      result = described_class.restore(statement_file, redacted_data)

      expect(result).to be_success
      expect(result.payload[:transactions].first["description"])
        .to eq("Transfer to John Smith CLABE:012345678901234567")
    end

    context "when statement has no redaction map" do
      before do
        statement_file.update(redaction_map: nil)
      end

      it "returns data unchanged" do
        result = described_class.restore(statement_file, redacted_data)

        expect(result).to be_success
        expect(result.payload).to eq(redacted_data)
      end
    end
  end
end
