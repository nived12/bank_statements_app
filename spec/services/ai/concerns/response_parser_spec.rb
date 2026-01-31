require 'rails_helper'

RSpec.describe Ai::Concerns::ResponseParser do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include Ai::Concerns::ResponseParser

      def initialize
        @errors = ActiveModel::Errors.new(self)
      end

      def errors
        @errors
      end

      def success(payload = nil)
        OpenStruct.new(success?: true, payload: payload)
      end

      def failure
        OpenStruct.new(success?: false)
      end
    end
  end

  let(:parser) { test_class.new }

  describe "#parse_ai_response" do
    it "parses valid JSON response" do
      content = '{"transactions": [{"description": "Test", "amount": "100"}]}'
      extraction_source = "ai_enhanced_parser"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be true
      expect(result.payload["transactions"]).to eq([{ "description" => "Test", "amount" => "100" }])
      expect(result.payload["extraction_source"]).to eq("ai_enhanced_parser")
      expect(result.payload["financial_summaries"]).to eq([])
      expect(result.payload["opening_balance"]).to be_nil
      expect(result.payload["closing_balance"]).to be_nil
    end

    it "handles empty transactions array" do
      content = '{"transactions": []}'
      extraction_source = "ai_parser_fallback"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be true
      expect(result.payload["transactions"]).to eq([])
      expect(result.payload["extraction_source"]).to eq("ai_parser_fallback")
    end

    it "handles missing transactions key" do
      content = '{"other_key": "value"}'
      extraction_source = "ai_enhanced_parser"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be true
      expect(result.payload["transactions"]).to eq([])
      expect(result.payload["extraction_source"]).to eq("ai_enhanced_parser")
    end

    it "includes financial summary data when present" do
      content = '{"transactions": [], "financial_summaries": [{"type": "balance"}], "opening_balance": "100.00", ' \
                '"closing_balance": "200.00"}'
      extraction_source = "ai_post_processor"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be true
      expect(result.payload["financial_summaries"]).to eq([{ "type" => "balance" }])
      expect(result.payload["opening_balance"]).to eq("100.00")
      expect(result.payload["closing_balance"]).to eq("200.00")
    end

    it "handles invalid JSON gracefully" do
      content = 'invalid json'
      extraction_source = "ai_enhanced_parser"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be false
      expect(parser.errors[:base].first).to start_with("Failed to parse AI response as JSON:")
    end

    it "handles nil content gracefully" do
      content = nil
      extraction_source = "ai_enhanced_parser"

      result = parser.parse_ai_response(content, extraction_source)

      expect(result.success?).to be false
      expect(parser.errors[:base].first).to start_with("Failed to parse AI response as JSON:")
    end
  end
end
