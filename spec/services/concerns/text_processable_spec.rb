require 'rails_helper'

RSpec.describe TextProcessable do
  let(:test_instance) do
    Class.new do
      include TextProcessable
      include Configurable
      include PiiHandlingConcern
      include ErrorHandling
      attr_accessor :statement

      def initialize
        statement_obj = Object.new
        statement_obj.define_singleton_method(:id) { 1 }

        bank_account_obj = Object.new
        bank_account_obj.define_singleton_method(:bank_name) { "bbva" }
        statement_obj.define_singleton_method(:bank_account) { bank_account_obj }

        @statement = statement_obj
      end
    end.new
  end

  describe "#extract_and_process_text" do
    it "extracts and processes text from file" do
      allow(TextExtractor).to receive(:extract_text_layer).and_return("extracted text")
      allow(TextExtractor).to receive(:valid_text?).and_return(true)
      allow(test_instance).to receive(:apply_pii_redaction).and_return("redacted text")
      allow(test_instance).to receive(:extract_financial_data).and_return({ "balance" => 1000 })
      allow(test_instance).to receive(:prepare_text_chunks).and_return([ "chunk1", "chunk2" ])

      result = test_instance.send(:extract_and_process_text, "test_file.pdf", test_instance.statement)

      expect(result).to be_a(Hash)
      expect(result[:text]).to eq("redacted text")
      expect(result[:text_chunks]).to eq([ "chunk1", "chunk2" ])
      expect(result[:financial_data]).to eq({ "balance" => 1000 })
      expect(result[:source]).to eq("text")
    end
  end

  describe "#extract_financial_data" do
    it "delegates to FinancialDataExtractor" do
      allow(test_instance).to receive(:detect_bank_type).with("bbva").and_return("bbva")
      allow(FinancialDataExtractor).to receive(:new).with("bbva").and_return(
        double("extractor", extract_financial_data: { "balance" => 1000 })
      )

      result = test_instance.send(:extract_financial_data, "test text", bank_name: "bbva")

      expect(result).to eq({ "balance" => 1000 })
    end

    it "uses generic bank type when bank_name is blank" do
      allow(test_instance).to receive(:detect_bank_type).with(nil).and_return("generic")
      allow(FinancialDataExtractor).to receive(:new).with("generic").and_return(
        double("extractor", extract_financial_data: { "balance" => 0 })
      )

      result = test_instance.send(:extract_financial_data, "test text")

      expect(result).to eq({ "balance" => 0 })
    end
  end

  describe "#prepare_text_chunks" do
    it "returns single chunk when text is short enough" do
      result = test_instance.send(:prepare_text_chunks, "short text", max_length: 100)
      expect(result).to eq([ "short text" ])
    end

    it "chunks text when it exceeds max length" do
      # Mock the Ai::TextProcessor to return a failure so it falls back to simple chunking
      allow(Ai::TextProcessor).to receive(:new).and_return(
        double("TextProcessor", chunk_by_transaction_count: double("result", success?: false))
      )

      long_text = "a" * 200
      result = test_instance.send(:prepare_text_chunks, long_text, max_length: 100)
      expect(result.length).to eq(2)
      expect(result.first.length).to be <= 100
    end

    it "uses default chunk size when not specified" do
      # Mock the Ai::TextProcessor to return a failure so it falls back to simple chunking
      allow(Ai::TextProcessor).to receive(:new).and_return(
        double("TextProcessor", chunk_by_transaction_count: double("result", success?: false))
      )

      long_text = "a" * 10000
      result = test_instance.send(:prepare_text_chunks, long_text)
      expect(result.length).to be > 1
    end
  end

  describe "#chunk_text_for_ai" do
    it "splits text into chunks of specified size" do
      text = "a" * 200
      result = test_instance.send(:chunk_text_for_ai, text, chunk_size: 100)
      expect(result.length).to eq(2)
      expect(result.first.length).to be <= 100
    end

    it "handles multiline text correctly" do
      text = "line1\nline2\nline3"
      result = test_instance.send(:chunk_text_for_ai, text, chunk_size: 10)
      expect(result).to be_an(Array)
    end
  end

  describe "#detect_bank_type" do
    it "returns generic when bank_name is blank" do
      result = test_instance.send(:detect_bank_type, nil)
      expect(result).to eq("generic")
    end

    it "returns lowercase bank name when present" do
      result = test_instance.send(:detect_bank_type, "BBVA")
      expect(result).to eq("bbva")
    end
  end
end
