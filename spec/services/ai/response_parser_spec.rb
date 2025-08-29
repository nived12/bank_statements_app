# spec/services/ai/response_parser_spec.rb
require "rails_helper"

RSpec.describe Ai::ResponseParser do
  let(:parser) { described_class.new }

  describe "#parse" do
    context "with valid JSON content" do
      let(:content) do
        {
          "transactions" => [
            {
              "description" => "SPEI ENVIADO",
              "amount" => -100.0,
              "category" => "Servicios"
            }
          ]
        }.to_json
      end

      it "parses valid JSON and returns structured data" do
        result = parser.parse(content, "ai_enhanced_parser")

        expect(result.success?).to be true
        expect(result.payload["transactions"]).to be_an(Array)
        expect(result.payload["transactions"].length).to eq(1)
        expect(result.payload["extraction_source"]).to eq("ai_enhanced_parser")
        expect(result.payload["transactions"][0]["description"]).to eq("SPEI ENVIADO")
      end

      it "handles empty transactions array" do
        content_with_empty = { "transactions" => [] }.to_json
        result = parser.parse(content_with_empty, "ai_parser_fallback")

        expect(result.success?).to be true
        expect(result.payload["transactions"]).to eq([])
        expect(result.payload["extraction_source"]).to eq("ai_parser_fallback")
      end

      it "handles missing transactions key" do
        content_without_transactions = { "other_data" => "value" }.to_json
        result = parser.parse(content_without_transactions, "ai_enhanced_parser")

        expect(result.success?).to be true
        expect(result.payload["transactions"]).to eq([])
        expect(result.payload["extraction_source"]).to eq("ai_enhanced_parser")
      end
    end

    context "with invalid JSON content" do
      let(:invalid_content) { "invalid json content" }

      before { allow(Rails.logger).to receive(:warn) }

      it "logs a warning and returns failure" do
        result = parser.parse(invalid_content, "ai_enhanced_parser")

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("AI returned invalid JSON: unexpected character: 'invalid' at line 1 column 1")
      end

      it "handles malformed JSON" do
        malformed_content = '{"transactions": [{"description": "test"}]'
        result = parser.parse(malformed_content, "ai_parser_fallback")

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("AI returned invalid JSON: expected ',' or '}' after object value, got: EOF at line 1 column 43")
      end
    end

    context "with complex transaction data" do
      let(:content) do
        {
          "transactions" => [
            {
              "description" => "SPEI ENVIADO 100.00",
              "amount" => -100.0,
              "category" => "Servicios",
              "sub_category" => "Transferencias",
              "merchant" => "Merchant Name",
              "transaction_type" => "variable_expense",
              "confidence" => 0.95,
              "category_confidence" => 0.90
            },
            {
              "description" => "DEPOSITO NOMINA",
              "amount" => 2000.0,
              "category" => "Ingresos",
              "sub_category" => nil,
              "merchant" => nil,
              "transaction_type" => "income",
              "confidence" => 0.98,
              "category_confidence" => 0.95
            }
          ]
        }.to_json
      end

      it "parses complex transaction structures correctly" do
        result = parser.parse(content, "ai_enhanced_parser")

        expect(result.success?).to be true
        expect(result.payload["transactions"].length).to eq(2)
        
        first_transaction = result.payload["transactions"][0]
        expect(first_transaction["description"]).to eq("SPEI ENVIADO 100.00")
        expect(first_transaction["amount"]).to eq(-100.0)
        expect(first_transaction["category"]).to eq("Servicios")
        expect(first_transaction["sub_category"]).to eq("Transferencias")
        expect(first_transaction["merchant"]).to eq("Merchant Name")
        expect(first_transaction["transaction_type"]).to eq("variable_expense")
        expect(first_transaction["confidence"]).to eq(0.95)
        expect(first_transaction["category_confidence"]).to eq(0.90)

        second_transaction = result.payload["transactions"][1]
        expect(second_transaction["description"]).to eq("DEPOSITO NOMINA")
        expect(second_transaction["amount"]).to eq(2000.0)
        expect(second_transaction["category"]).to eq("Ingresos")
        expect(second_transaction["sub_category"]).to be_nil
        expect(second_transaction["merchant"]).to be_nil
        expect(second_transaction["transaction_type"]).to eq("income")
        expect(second_transaction["confidence"]).to eq(0.98)
        expect(second_transaction["category_confidence"]).to eq(0.95)
      end
    end

    context "with invalid input" do
      it "returns failure for nil content" do
        result = parser.parse(nil, "ai_enhanced_parser")

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("content and extraction_source must be Strings")
      end

      it "returns failure for nil extraction_source" do
        result = parser.parse('{"transactions": []}', nil)

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("content and extraction_source must be Strings")
      end

      it "returns failure for non-string content" do
        result = parser.parse(123, "ai_enhanced_parser")

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("content and extraction_source must be Strings")
      end

      it "returns failure for non-string extraction_source" do
        result = parser.parse('{"transactions": []}', 456)

        expect(result.success?).to be false
        expect(parser.errors[:base]).to include("content and extraction_source must be Strings")
      end
    end
  end
end
