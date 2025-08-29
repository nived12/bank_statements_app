# spec/services/ai/text_processor_spec.rb
require "rails_helper"

RSpec.describe Ai::TextProcessor do
  let(:processor) { described_class.new }

  describe "#parsed_transactions?" do
    context "with transaction-like text" do
      let(:text) { "SPEI ENVIADO\nDEPOSITO NOMINA\nRETIRO SIN TARJETA" }

      it "identifies as parsed transactions" do
        result = processor.parsed_transactions?(text)

        expect(result.success?).to be true
        expect(result.payload).to be true
      end
    end

    context "with mixed text" do
      let(:text) { "Some header text\nSPEI ENVIADO\nMore text\nDEPOSITO NOMINA\nRETIRO SIN TARJETA\nPAGO INTERBANCARIO" }

      it "identifies as parsed transactions when majority are transaction-like" do
        result = processor.parsed_transactions?(text)

        expect(result.success?).to be true
        expect(result.payload).to be true
      end
    end

    context "with non-transaction text" do
      let(:text) { "Bank statement header\nAccount information\nBalance details" }

      it "identifies as raw text" do
        result = processor.parsed_transactions?(text)

        expect(result.success?).to be true
        expect(result.payload).to be false
      end
    end

    it "returns failure for invalid input" do
      result = processor.parsed_transactions?(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#extract_keywords_inline" do
    let(:text) { "SPEI ENVIADO 100.00\nDEPOSITO NOMINA 2000.00\nRETIRO SIN TARJETA 500.00" }

    it "extracts first few words from each line" do
      result = processor.extract_keywords_inline(text)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines[0]).to eq("SPEI ENVIADO 100.00")
      expect(lines[1]).to eq("DEPOSITO NOMINA 2000.00")
      expect(lines[2]).to eq("RETIRO SIN TARJETA 500.00")
    end

    it "handles empty lines" do
      text_with_empty = "SPEI ENVIADO\n\nDEPOSITO NOMINA"
      result = processor.extract_keywords_inline(text_with_empty)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines).to eq([ "SPEI ENVIADO", "DEPOSITO NOMINA" ])
    end

    it "returns failure for invalid input" do
      result = processor.extract_keywords_inline(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#shorten_transaction_descriptions" do
    let(:text) { "SPEI ENVIADO 100.00 TO MERCHANT\nDEPOSITO NOMINA 2000.00 FROM EMPLOYER" }

    it "keeps important keywords and limits word count" do
      result = processor.shorten_transaction_descriptions(text)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines[0]).to include("SPEI ENVIADO")
      expect(lines[1]).to include("DEPOSITO NOMINA")
    end

    it "returns failure for invalid input" do
      result = processor.shorten_transaction_descriptions(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#extract_essential_transaction_keywords" do
    let(:text) { "SPEI ENVIADO 100.00 TO MERCHANT\nDEPOSITO NOMINA 2000.00 FROM EMPLOYER" }

    it "extracts only essential banking keywords" do
      result = processor.extract_essential_transaction_keywords(text)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines[0]).to include("SPEI ENVIADO")
      expect(lines[1]).to include("DEPOSITO NOMINA")
    end

    it "falls back to first few words when no keywords found" do
      text_no_keywords = "Random text here\nAnother random line"
      result = processor.extract_essential_transaction_keywords(text_no_keywords)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines[0]).to eq("Random text here")
      expect(lines[1]).to eq("Another random line")
    end

    it "returns failure for invalid input" do
      result = processor.extract_essential_transaction_keywords(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#extract_keywords_simple" do
    let(:text) { "SPEI ENVIADO 100.00\nDEPOSITO NOMINA 2000.00" }

    it "extracts simple keywords" do
      result = processor.extract_keywords_simple(text)

      expect(result.success?).to be true
      lines = result.payload.split("\n")

      expect(lines[0]).to eq("SPEI ENVIADO 100.00")
      expect(lines[1]).to eq("DEPOSITO NOMINA 2000.00")
    end

    it "returns failure for invalid input" do
      result = processor.extract_keywords_simple(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#chunk_by_transaction_count" do
    let(:text) do
      "SPEI ENVIADO 100.00\nDEPOSITO NOMINA 2000.00\nRETIRO SIN TARJETA 500.00\n" \
      "PAGO INTERBANCARIO 300.00\nSPEI RECIBIDO 150.00\nDEPOSITO TERCERO 800.00\n" \
      "PAGO CUENTA 250.00\nRETIRO 400.00\nSPEI ENVIADO 600.00\nDEPOSITO 900.00"
    end

    it "chunks text based on transaction count" do
      result = processor.chunk_by_transaction_count(text)

      expect(result.success?).to be true
      chunks = result.payload

      expect(chunks.length).to be >= 1
      expect(chunks.first).to include("SPEI ENVIADO")
      expect(chunks.first).to include("DEPOSITO NOMINA")
    end

    it "returns failure for invalid input" do
      result = processor.chunk_by_transaction_count(nil)

      expect(result.success?).to be false
      expect(processor.errors[:base]).to include("Input must be a String")
    end
  end

  describe "#transaction_line?" do
    it "identifies date patterns" do
      expect(processor.send(:transaction_line?, "15-ene-2025")).to be true
    end

    it "identifies amount patterns" do
      expect(processor.send(:transaction_line?, "+ $1,234.56")).to be true
      expect(processor.send(:transaction_line?, "- 567.89")).to be true
    end

    it "identifies banking keywords" do
      expect(processor.send(:transaction_line?, "SPEI ENVIADO")).to be true
      expect(processor.send(:transaction_line?, "DEPOSITO NOMINA")).to be true
    end

    it "rejects non-transaction lines" do
      expect(processor.send(:transaction_line?, "Bank statement")).to be false
      expect(processor.send(:transaction_line?, "Account summary")).to be false
    end

    it "handles non-string input" do
      expect(processor.send(:transaction_line?, nil)).to be false
      expect(processor.send(:transaction_line?, 123)).to be false
    end
  end
end
