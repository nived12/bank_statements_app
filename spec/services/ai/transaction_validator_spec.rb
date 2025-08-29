# spec/services/ai/transaction_validator_spec.rb
require "rails_helper"

RSpec.describe Ai::TransactionValidator do
  let(:validator) { described_class.new }

  describe "#normalize!" do
    let(:json) do
      {
        "transactions" => [
          { "amount" => 100.0 },
          { "amount" => -50.0, "confidence" => 0.95 }
        ]
      }
    end

    it "ensures required fields are present" do
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][0]["category"]).to eq("Sin Categorizar")
      expect(result.payload["transactions"][0]["transaction_type"]).to eq("variable_expense")
      expect(result.payload["transactions"][1]["category"]).to eq("Sin Categorizar")
      expect(result.payload["transactions"][1]["transaction_type"]).to eq("variable_expense")
    end

    it "normalizes confidence values" do
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][1]["confidence"]).to eq(0.95)
    end

    it "clamps confidence values to valid range" do
      json["transactions"][0]["confidence"] = 1.5
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][0]["confidence"]).to eq(1.0)
    end

    it "returns failure for invalid input" do
      result = validator.normalize!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash")
    end
  end

  describe "#validate_spanish_banking_terms!" do
    let(:json) do
      {
        "transactions" => [
          {
            "raw_text" => "IMPORTE CARGOS 100.00",
            "amount" => 100.0,
            "transaction_type" => "income"
          },
          {
            "raw_text" => "IMPORTE ABONOS 200.00",
            "amount" => -200.0,
            "transaction_type" => "variable_expense"
          }
        ]
      }
    end

    before { allow(Rails.logger).to receive(:warn) }

    it "corrects CARGOS amounts to negative" do
      result = validator.validate_spanish_banking_terms!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][0]["amount"]).to eq(-100.0)
      expect(result.payload["transactions"][0]["transaction_type"]).to eq("variable_expense")
      expect(result.payload["transactions"][0]["bank_entry_type"]).to eq("debit")
    end

    it "corrects ABONOS amounts to positive" do
      result = validator.validate_spanish_banking_terms!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][1]["amount"]).to eq(200.0)
      expect(result.payload["transactions"][1]["transaction_type"]).to eq("income")
      expect(result.payload["transactions"][1]["bank_entry_type"]).to eq("credit")
    end

    it "returns failure for invalid input" do
      result = validator.validate_spanish_banking_terms!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash with transactions")
    end
  end

  describe "#validate_bbva_credit_card!" do
    let(:json) do
      {
        "transactions" => [
          {
            "raw_text" => "ANUALIDAD TARJETA",
            "amount" => 500.0,
            "transaction_type" => "income"
          },
          {
            "raw_text" => "PAGO TDC",
            "amount" => -1000.0,
            "transaction_type" => "variable_expense"
          }
        ]
      }
    end

    before { allow(Rails.logger).to receive(:warn) }

    it "corrects annual fees to negative" do
      result = validator.validate_bbva_credit_card!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][0]["amount"]).to eq(-500.0)
      expect(result.payload["transactions"][0]["transaction_type"]).to eq("variable_expense")
      expect(result.payload["transactions"][0]["bank_entry_type"]).to eq("debit")
    end

    it "corrects credit card payments to positive" do
      result = validator.validate_bbva_credit_card!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][1]["amount"]).to eq(1000.0)
      expect(result.payload["transactions"][1]["transaction_type"]).to eq("income")
      expect(result.payload["transactions"][1]["bank_entry_type"]).to eq("credit")
    end

    it "returns failure for invalid input" do
      result = validator.validate_bbva_credit_card!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash with transactions")
    end
  end

  describe "#validate_transaction_types!" do
    let(:json) do
      {
        "transactions" => [
          {
            "amount" => -100.0,
            "transaction_type" => "income",
            "bank_entry_type" => "credit"
          },
          {
            "amount" => 200.0,
            "transaction_type" => "variable_expense",
            "bank_entry_type" => "debit"
          }
        ]
      }
    end

    before { allow(Rails.logger).to receive(:warn) }

    it "corrects transaction types based on amount signs" do
      result = validator.validate_transaction_types!(json)

      expect(result.success?).to be true
      expect(result.payload["transactions"][0]["transaction_type"]).to eq("variable_expense")
      expect(result.payload["transactions"][0]["bank_entry_type"]).to eq("debit")
      expect(result.payload["transactions"][1]["transaction_type"]).to eq("income")
      expect(result.payload["transactions"][1]["bank_entry_type"]).to eq("credit")
    end

    it "returns failure for invalid input" do
      result = validator.validate_transaction_types!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash with transactions")
    end
  end

  describe "#validate_transaction_type!" do
    let(:transaction) do
      {
        "amount" => -100.0,
        "transaction_type" => "income",
        "bank_entry_type" => "credit"
      }
    end

    before { allow(Rails.logger).to receive(:warn) }

    it "corrects transaction type based on amount sign" do
      result = validator.validate_transaction_type!(transaction)

      expect(result.success?).to be true
      expect(result.payload["transaction_type"]).to eq("variable_expense")
      expect(result.payload["bank_entry_type"]).to eq("debit")
    end

    it "returns failure for invalid input" do
      result = validator.validate_transaction_type!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash")
    end
  end

  describe "#normalize_balance" do
    it "handles string balances with commas" do
      result = validator.normalize_balance("1,234.56")

      expect(result.success?).to be true
      expect(result.payload).to eq(1234.56)
    end

    it "handles numeric balances" do
      result = validator.normalize_balance(1234.56)

      expect(result.success?).to be true
      expect(result.payload).to eq(1234.56)
    end

    it "handles nil balances" do
      result = validator.normalize_balance(nil)

      expect(result.success?).to be true
      expect(result.payload).to be_nil
    end

    it "handles other types" do
      result = validator.normalize_balance("123")

      expect(result.success?).to be true
      expect(result.payload).to eq(123.0)
    end
  end
end
