require 'rails_helper'

RSpec.describe Ai::Concerns::TextAnalysis do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include Ai::Concerns::TextAnalysis

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

  let(:analyzer) { test_class.new }

  describe "#parsed_transactions?" do
    it "returns true for text that looks like parsed transactions" do
      text = <<~TEXT
        03/01/2025 Pago Nómina EMPRESA SA 15,000.00
        05/01/2025 OXXO Compra -89.00
        07/01/2025 Netflix -199.00
        10/01/2025 SPEI ENVIADO BANCO 25,000.00
      TEXT

      result = analyzer.parsed_transactions?(text)

      expect(result.success?).to be true
      expect(result.payload).to be true
    end

    it "returns false for text that doesn't look like transactions" do
      text = <<~TEXT
        Bank Statement
        Account: 1234567890
        Period: January 2025
        Total Balance: $50,000.00
      TEXT

      result = analyzer.parsed_transactions?(text)

      expect(result.success?).to be true
      expect(result.payload).to be false
    end

    it "handles mixed content appropriately" do
      text = <<~TEXT
        Bank Statement
        03/01/2025 Pago Nómina EMPRESA SA 15,000.00
        Account: 1234567890
        05/01/2025 OXXO Compra -89.00
        Period: January 2025
      TEXT

      result = analyzer.parsed_transactions?(text)

      expect(result.success?).to be true
      # Should be true because 2 out of 5 lines are transactions (40% > 30%)
      expect(result.payload).to be true
    end

    it "handles nil input gracefully" do
      result = analyzer.parsed_transactions?(nil)

      expect(result.success?).to be false
      expect(analyzer.errors[:base].first).to start_with("Failed to analyze text")
    end
  end

  describe "#extract_keywords_inline" do
    it "extracts essential transaction information" do
      text = <<~TEXT
        03/01/2025 Pago Nómina EMPRESA SA 15,000.00
        Some header text
        05/01/2025 OXXO Compra -89.00
        Another non-transaction line
      TEXT

      result = analyzer.extract_keywords_inline(text)

      expect(result.success?).to be true
      extracted = result.payload
      expect(extracted).to include("Pago Nómina EMPRESA SA 15,000.00")
      expect(extracted).to include("OXXO Compra -89.00")
      expect(extracted).not_to include("Some header text")
      expect(extracted).not_to include("Another non-transaction line")
    end

    it "handles empty text" do
      result = analyzer.extract_keywords_inline("")

      expect(result.success?).to be true
      expect(result.payload).to eq("")
    end

    it "handles nil input gracefully" do
      result = analyzer.extract_keywords_inline(nil)

      expect(result.success?).to be false
      expect(analyzer.errors[:base].first).to start_with("Failed to extract keywords")
    end
  end

  describe "#transaction_line?" do
    it "identifies transaction lines correctly" do
      expect(analyzer.send(:transaction_line?, "03/01/2025 Pago Nómina EMPRESA SA 15,000.00")).to be true
      expect(analyzer.send(:transaction_line?, "05/01/2025 OXXO Compra -89.00")).to be true
      expect(analyzer.send(:transaction_line?, "SPEI ENVIADO BANCO 25,000.00")).to be true
      expect(analyzer.send(:transaction_line?, "Netflix -199.00")).to be true
    end

    it "rejects non-transaction lines" do
      expect(analyzer.send(:transaction_line?, "Bank Statement")).to be false
      expect(analyzer.send(:transaction_line?, "Total Balance: $50,000.00")).to be false
      expect(analyzer.send(:transaction_line?, "Account: 1234567890")).to be false
      expect(analyzer.send(:transaction_line?, "")).to be false
    end
  end
end
