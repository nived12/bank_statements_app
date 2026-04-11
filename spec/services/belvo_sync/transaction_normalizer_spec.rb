require "rails_helper"

RSpec.describe BelvoSync::TransactionNormalizer do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }

  describe ".call" do
    let(:belvo_transaction) do
      {
        "id" => SecureRandom.uuid,
        "value_date" => "2026-04-01",
        "description" => "PAGO SERVICIO NETFLIX",
        "amount" => -199.00,
        "type" => "OUTFLOW",
        "reference" => "REF123456",
        "merchant" => { "name" => "Netflix" }
      }
    end

    it "normalizes a Belvo transaction to local attributes" do
      result = described_class.call(belvo_transaction: belvo_transaction, bank_account: bank_account)
      expect(result).to be_success

      attrs = result.payload
      expect(attrs[:user]).to eq(user)
      expect(attrs[:bank_account]).to eq(bank_account)
      expect(attrs[:belvo_transaction_id]).to eq(belvo_transaction["id"])
      expect(attrs[:date]).to eq(Date.parse("2026-04-01"))
      expect(attrs[:description]).to eq("PAGO SERVICIO NETFLIX")
      expect(attrs[:amount]).to eq(-199.00)
      expect(attrs[:transaction_type]).to eq("variable_expense")
      expect(attrs[:source]).to eq(:bank_api)
      expect(attrs[:merchant]).to eq("Netflix")
      expect(attrs[:confidence]).to eq(0.95)
    end

    context "with INFLOW type" do
      let(:belvo_transaction) do
        {
          "id" => SecureRandom.uuid,
          "value_date" => "2026-04-01",
          "description" => "NOMINA EMPRESA SA",
          "amount" => 15000.00,
          "type" => "INFLOW",
          "reference" => nil,
          "merchant" => nil
        }
      end

      it "maps to income" do
        result = described_class.call(belvo_transaction: belvo_transaction, bank_account: bank_account)
        expect(result.payload[:transaction_type]).to eq("income")
      end
    end

    context "with category rule matching" do
      before do
        parent_category = create(:category, user: user, name: "Entertainment")
        create(:category_rule, user: user, category: parent_category, pattern: "netflix", match_type: "contains")
      end

      it "applies category from rules" do
        result = described_class.call(belvo_transaction: belvo_transaction, bank_account: bank_account)
        expect(result.payload[:category_id]).to be_present
        expect(result.payload[:category_confidence]).to eq(0.95)
      end
    end

    it "derives concept by stripping noise" do
      tx = belvo_transaction.merge("description" => "SPEI ENVIADO BNET 1234567890 PAGO RENTA")
      result = described_class.call(belvo_transaction: tx, bank_account: bank_account)
      expect(result.payload[:concept]).not_to include("1234567890")
    end
  end
end
