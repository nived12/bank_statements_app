# frozen_string_literal: true

require "rails_helper"

RSpec.describe ParsingStrategies do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new(ApplicationService) do
      include ParsingStrategies
      include Configurable
    end
  end

  let(:test_instance) { test_class.new }

  let(:parser_result) { { "transactions" => [ "tx1", "tx2" ] } }
  let(:ai_result) { double("AIResponse", success?: true, payload: { "transactions" => [ "ai_tx1" ] }) }
  let(:enhanced_result) { { "transactions" => [ "enhanced_tx1" ] } }
  let(:merged_result) { { "transactions" => [ "merged_tx1" ], "ai_enhancement" => true } }

  before do
    allow(test_instance).to receive(:ai_api_available?).and_return(true)
    allow(test_instance).to receive(:parse_with_deterministic_parser).and_return(parser_result)
    allow(test_instance).to receive(:parse_with_ai).and_return(ai_result)
    allow(test_instance).to receive(:parse_with_ai_enhancement).and_return(enhanced_result)
    allow(test_instance).to receive(:merge_ai_categorization_with_parser_transactions).and_return(merged_result)
  end

  describe "#parse_hybrid" do
    it "tries parser first and enhances with AI if successful" do
      result = test_instance.send(:parse_hybrid, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("merged_tx1")
      expect(result.success?).to be true
      expect(result.payload["ai_enhancement"]).to be true
    end

    it "falls back to AI when parser fails" do
      allow(test_instance).to receive(:parse_with_deterministic_parser).and_return({ "transactions" => [] })

      result = test_instance.send(:parse_hybrid, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("ai_tx1")
      expect(result.success?).to be true
      expect(result.payload["extraction_source"]).to eq("ai_parser_fallback")
    end

    it "returns empty result when both parser and AI fail" do
      allow(test_instance).to receive(:parse_with_deterministic_parser).and_return({ "transactions" => [] })
      allow(test_instance).to receive(:parse_with_ai).and_return(nil)

      result = test_instance.send(:parse_hybrid, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to eq([])
      expect(result.success?).to be true
      expect(result.payload["financial_summaries"]).to eq([])
    end
  end

  describe "#parse_ai_first" do
    it "tries AI first when available" do
      result = test_instance.send(:parse_ai_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("ai_tx1")
    end

    it "falls back to parser when AI fails" do
      allow(test_instance).to receive(:parse_with_ai).and_return(nil)

      result = test_instance.send(:parse_ai_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("tx1", "tx2")
    end

    it "uses parser when AI is not available" do
      allow(test_instance).to receive(:ai_api_available?).and_return(false)

      result = test_instance.send(:parse_ai_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("tx1", "tx2")
    end
  end

  describe "#parse_parser_first" do
    it "uses parser result when successful" do
      result = test_instance.send(:parse_parser_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("tx1", "tx2")
    end

    it "tries AI when parser fails and AI is available" do
      allow(test_instance).to receive(:parse_with_deterministic_parser).and_return({ "transactions" => [] })

      result = test_instance.send(:parse_parser_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("ai_tx1")
    end

    it "returns empty result when both parser and AI fail" do
      allow(test_instance).to receive(:parse_with_deterministic_parser).and_return({ "transactions" => [] })
      allow(test_instance).to receive(:ai_api_available?).and_return(false)

      result = test_instance.send(:parse_parser_first, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.success?).to be true
      expect(result.payload["transactions"]).to eq([])
      expect(result.success?).to be true
      expect(result.payload["financial_summaries"]).to eq([])
    end
  end

  describe "#parse_generic" do
    it "tries AI when available" do
      result = test_instance.send(:parse_generic, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("ai_tx1")
    end

    it "uses parser when AI is not available" do
      allow(test_instance).to receive(:ai_api_available?).and_return(false)

      result = test_instance.send(:parse_generic, [ "chunk1" ], "text")

      expect(result.success?).to be true
      expect(result.payload["transactions"]).to include("tx1", "tx2")
    end
  end

  describe "#enhance_with_ai_if_available" do
    it "enhances parser result with AI when available" do
      parser_result = { "transactions" => [ "tx1" ] }

      result = test_instance.send(:enhance_with_ai_if_available, parser_result)

      expect(result["transactions"]).to include("merged_tx1")
      expect(result["ai_enhancement"]).to be true
      expect(result["extraction_source"]).to eq("ai_enhanced_parser")
    end

    it "returns parser result when AI enhancement fails" do
      allow(test_instance).to receive(:parse_with_ai_enhancement).and_return(nil)
      parser_result = { "transactions" => [ "tx1" ] }

      result = test_instance.send(:enhance_with_ai_if_available, parser_result)

      expect(result["transactions"]).to include("tx1")
      expect(result["extraction_source"]).to eq("parser_with_basic_categorization")
    end

    it "returns parser result when AI is not available" do
      allow(test_instance).to receive(:ai_api_available?).and_return(false)
      parser_result = { "transactions" => [ "tx1" ] }

      result = test_instance.send(:enhance_with_ai_if_available, parser_result)

      expect(result).to eq(parser_result)
    end
  end

  describe "#empty_result" do
    it "returns empty result structure" do
      result = test_instance.send(:empty_result)

      expect(result["transactions"]).to eq([])
      expect(result["financial_summaries"]).to eq([])
    end
  end
end
