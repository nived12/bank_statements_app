# frozen_string_literal: true

require "rails_helper"

RSpec.describe TextProcessable do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include TextProcessable
      include TextFilteringPatterns
      include Configurable

      attr_accessor :statement

      def initialize(statement)
        @statement = statement
      end
    end
  end

  let(:statement) { double("Statement", bank_account: double("BankAccount", bank_name: "bbva")) }
  let(:test_instance) { test_class.new(statement) }

  describe "#extract_financial_data" do
    it "delegates to FinancialDataExtractor" do
      extractor = double("FinancialDataExtractor")
      allow(FinancialDataExtractor).to receive(:new).with("bbva").and_return(extractor)
      allow(extractor).to receive(:extract_financial_data).with("test text").and_return({ "balance" => 1000 })

      result = test_instance.send(:extract_financial_data, "test text", bank_name: "bbva")

      expect(result).to eq({ "balance" => 1000 })
    end

    it "uses generic bank type when bank_name is blank" do
      extractor = double("FinancialDataExtractor")
      allow(FinancialDataExtractor).to receive(:new).with("generic").and_return(extractor)
      allow(extractor).to receive(:extract_financial_data).with("test text").and_return({ "balance" => 1000 })

      result = test_instance.send(:extract_financial_data, "test text")

      expect(result).to eq({ "balance" => 1000 })
    end
  end

  describe "#filter_for_transactions" do
    it "cleans and filters text for transactions" do
      allow(test_instance).to receive(:clean_corrupted_text).with("test text").and_return("cleaned text")
      allow(test_instance).to receive(:detect_bank_type).with("bbva").and_return("bbva")
      allow(test_instance).to receive(:get_patterns_for_bank).with("bbva").and_return({
        transaction: [ /test/ ],
        codes: [],
        non_transaction: [],
        strong: []
      })
      allow(test_instance).to receive(:split_text_into_lines).with("cleaned text").and_return([ "line 1", "line 2" ])
      allow(test_instance).to receive(:filter_lines).with([ "line 1", "line 2" ], anything, "bbva").and_return([ "filtered line" ])

      result = test_instance.send(:filter_for_transactions, "test text", bank_name: "bbva")

      expect(result).to eq("filtered line")
    end
  end

  describe "#prepare_text_chunks" do
    it "returns single chunk when text is short enough" do
      result = test_instance.send(:prepare_text_chunks, "short text", max_length: 100)
      expect(result).to eq([ "short text" ])
    end

    it "chunks text when it exceeds max length" do
      long_text = "a" * 200
      result = test_instance.send(:prepare_text_chunks, long_text, max_length: 100)
      expect(result.length).to eq(2)
      expect(result.first.length).to be <= 100
    end

    it "uses default chunk size when not specified" do
      allow(test_instance).to receive(:text_chunk_size).and_return(50)
      long_text = "a" * 100
      result = test_instance.send(:prepare_text_chunks, long_text)
      expect(result.length).to eq(2)
    end
  end

  describe "#chunk_text_for_ai" do
    it "splits text into chunks of specified size" do
      text = "a" * 25
      result = test_instance.send(:chunk_text_for_ai, text, chunk_size: 10)
      expect(result.length).to eq(3)
      expect(result.first.length).to eq(10)
      expect(result.last.length).to eq(5)
    end

    it "handles multiline text correctly" do
      text = "line1\nline2\nline3"
      result = test_instance.send(:chunk_text_for_ai, text, chunk_size: 10)
      expect(result).to be_an(Array)
    end
  end

  describe "#split_text_into_lines" do
    it "splits text with newlines" do
      text = "line1\nline2\nline3"
      result = test_instance.send(:split_text_into_lines, text)
      expect(result).to eq([ "line1", "line2", "line3" ])
    end

    it "reconstructs lines from PDF text without newlines" do
      text = "part1   part2   part3"
      allow(test_instance).to receive(:reconstruct_lines_from_pdf_text).with(text).and_return([ "reconstructed" ])

      result = test_instance.send(:split_text_into_lines, text)
      expect(result).to eq([ "reconstructed" ])
    end
  end

  describe "#clean_corrupted_text" do
    it "removes invalid ASCII control characters" do
      text = "normal\x00text\x1Fwith\x7Fcontrol"
      result = test_instance.send(:clean_corrupted_text, text)
      expect(result).to eq("normaltextwithcontrol")
    end

    it "removes placeholder characters" do
      text = "normal▯text▯with▯placeholders"
      result = test_instance.send(:clean_corrupted_text, text)
      expect(result).to eq("normaltextwithplaceholders")
    end

    it "normalizes whitespace" do
      text = "text   with    multiple     spaces\n\n\nand\n\n\nnewlines"
      result = test_instance.send(:clean_corrupted_text, text)
      expect(result).to eq("text with multiple spacesandnewlines")
    end

    it "returns original text if not a string" do
      text = 123
      result = test_instance.send(:clean_corrupted_text, text)
      expect(result).to eq(123)
    end
  end

  describe "#detect_bank_type" do
    it "returns generic when bank_name is blank" do
      result = test_instance.send(:detect_bank_type, nil)
      expect(result).to eq("generic")

      result = test_instance.send(:detect_bank_type, "")
      expect(result).to eq("generic")
    end

    it "returns lowercase bank name when present" do
      result = test_instance.send(:detect_bank_type, "BBVA")
      expect(result).to eq("bbva")

      result = test_instance.send(:detect_bank_type, "Santander")
      expect(result).to eq("santander")
    end
  end
end
