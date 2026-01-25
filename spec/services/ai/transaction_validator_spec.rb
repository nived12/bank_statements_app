# spec/services/ai/transaction_validator_spec.rb
require "rails_helper"

RSpec.describe Ai::TransactionValidator do
  let(:validator) { described_class.new }

  describe "#normalize!" do
    let(:json) do
      {
        "transactions" => [
          { "description" => "Test transaction", "amount" => 100.0 },
          { "description" => "Another transaction", "amount" => -50.0 }
        ]
      }
    end

    it "ensures required fields are present" do
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(json["transactions"][0]["transaction_type"]).to eq("variable_expense")
    end

    it "normalizes all confidence values" do
      json["transactions"][0]["confidence"] = 1.5
      json["transactions"][0]["category_confidence"] = 1.2
      json["transactions"][0]["transaction_type_confidence"] = 0.8
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(json["transactions"][0]["confidence"]).to eq(1.0)
      expect(json["transactions"][0]["category_confidence"]).to eq(1.0)
      expect(json["transactions"][0]["transaction_type_confidence"]).to eq(0.8)
    end

    it "clamps confidence values to valid range" do
      json["transactions"][0]["confidence"] = -0.5
      json["transactions"][0]["category_confidence"] = -0.2
      json["transactions"][0]["transaction_type_confidence"] = 1.5
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(json["transactions"][0]["confidence"]).to eq(0.0)
      expect(json["transactions"][0]["category_confidence"]).to eq(0.0)
      expect(json["transactions"][0]["transaction_type_confidence"]).to eq(1.0)
    end

    it "handles nil confidence values" do
      json["transactions"][0]["confidence"] = nil
      json["transactions"][0]["category_confidence"] = nil
      json["transactions"][0]["transaction_type_confidence"] = nil
      result = validator.normalize!(json)

      expect(result.success?).to be true
      expect(json["transactions"][0]["confidence"]).to be_nil
      expect(json["transactions"][0]["category_confidence"]).to be_nil
      expect(json["transactions"][0]["transaction_type_confidence"]).to be_nil
    end

    it "returns failure for invalid input" do
      result = validator.normalize!("invalid")

      expect(result.success?).to be false
      expect(validator.errors[:base]).to include("Input must be a Hash")
    end
  end
end
