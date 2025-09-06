# frozen_string_literal: true

require "rails_helper"

RSpec.describe TextFilteringPatterns do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include TextFilteringPatterns
    end
  end

  let(:test_instance) { test_class.new }

  describe "#get_patterns_for_bank" do
    context "BBVA patterns" do
      let(:patterns) { test_instance.send(:get_patterns_for_bank, "bbva") }

      it "returns BBVA-specific transaction patterns" do
        expect(patterns[:transaction]).to include(/\d{2}-[a-z]{3}-\d{4}/)
        expect(patterns[:transaction]).to include(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
        expect(patterns[:transaction]).to include(/\b[A-Z\s]{3,}\b/)
      end

      it "returns BBVA-specific non-transaction patterns" do
        expect(patterns[:non_transaction]).to include(/^Saldo (Promedio|Final):\s*[\d,]+\.\d{2}$/i)
        expect(patterns[:non_transaction]).to include(/^Total (Movimientos|Transacciones):\s*\d+$/i)
      end

      it "returns BBVA-specific strong patterns" do
        expect(patterns[:strong]).to include(/^BBVA\s+Bancomer/i)
        expect(patterns[:strong]).to include(/^Estado de Cuenta/i)
      end
    end

    context "Santander patterns" do
      let(:patterns) { test_instance.send(:get_patterns_for_bank, "santander") }

      it "returns Santander-specific transaction patterns" do
        expect(patterns[:transaction]).to include(/\d{2}\/\d{2}\/\d{4}/)
        expect(patterns[:transaction]).to include(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
      end

      it "returns Santander-specific non-transaction patterns" do
        expect(patterns[:non_transaction]).to include(/^Saldo (Anterior|Actual):\s*[\d,]+\.\d{2}$/i)
      end

      it "returns Santander-specific strong patterns" do
        expect(patterns[:strong]).to include(/^Banco Santander/i)
      end
    end

    context "Banorte patterns" do
      let(:patterns) { test_instance.send(:get_patterns_for_bank, "banorte") }

      it "returns Banorte-specific transaction patterns" do
        expect(patterns[:transaction]).to include(/\d{2}-\d{2}-\d{4}/)
        expect(patterns[:transaction]).to include(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
      end

      it "returns Banorte-specific strong patterns" do
        expect(patterns[:strong]).to include(/^Banorte/i)
      end
    end

    context "Banamex patterns" do
      let(:patterns) { test_instance.send(:get_patterns_for_bank, "banamex") }

      it "returns Banamex-specific transaction patterns" do
        expect(patterns[:transaction]).to include(/\d{2}\/\d{2}\/\d{4}/)
        expect(patterns[:transaction]).to include(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
      end

      it "returns Banamex-specific strong patterns" do
        expect(patterns[:strong]).to include(/^Banamex/i)
      end
    end

    context "Generic patterns" do
      let(:patterns) { test_instance.send(:get_patterns_for_bank, "generic") }

      it "returns generic transaction patterns" do
        expect(patterns[:transaction]).to include(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/)
        expect(patterns[:transaction]).to include(/[+\-]\s*\$?\s*[\d,]+\.?\d*/)
      end

      it "returns generic non-transaction patterns" do
        expect(patterns[:non_transaction]).to include(/^Saldo (Anterior|Actual|Final):\s*[\d,]+\.?\d*$/i)
      end
    end
  end

  describe "#should_keep_line?" do
    let(:patterns) do
      {
        transaction: [ /test/ ],
        codes: [ /CODE\d+/ ],
        non_transaction: [ /skip/ ],
        strong: [ /REJECT/ ]
      }
    end

    it "keeps lines matching transaction patterns" do
      result = test_instance.send(:should_keep_line?, "test line", patterns, "bbva")
      expect(result).to be true
    end

    it "keeps lines matching code patterns" do
      result = test_instance.send(:should_keep_line?, "CODE123", patterns, "bbva")
      expect(result).to be true
    end

    it "rejects lines matching non-transaction patterns" do
      result = test_instance.send(:should_keep_line?, "skip this line", patterns, "bbva")
      expect(result).to be false
    end

    it "rejects lines matching strong patterns" do
      result = test_instance.send(:should_keep_line?, "REJECT this line", patterns, "bbva")
      expect(result).to be false
    end

    it "delegates to is_potential_transaction_line? when no patterns match" do
      allow(test_instance).to receive(:is_potential_transaction_line?).with("unknown line", "bbva").and_return(true)

      result = test_instance.send(:should_keep_line?, "unknown line", patterns, "bbva")

      expect(result).to be true
      expect(test_instance).to have_received(:is_potential_transaction_line?).with("unknown line", "bbva")
    end
  end

  describe "#is_transaction_continuation?" do
    context "BBVA continuation logic" do
      it "identifies continuation lines for BBVA" do
        last_line = "15-jan-2024  -$50.00"
        continuation_line = "  MERCHANT NAME"

        result = test_instance.send(:is_transaction_continuation?, continuation_line, [ last_line ], "bbva")

        expect(result).to be true
      end

      it "rejects non-continuation lines for BBVA" do
        last_line = "15-jan-2024  -$50.00"
        non_continuation_line = "15-jan-2024  +$25.00"

        result = test_instance.send(:is_transaction_continuation?, non_continuation_line, [ last_line ], "bbva")

        expect(result).to be false
      end
    end

    context "Santander continuation logic" do
      it "identifies continuation lines for Santander" do
        last_line = "15/01/2024  -$50.00"
        continuation_line = "  MERCHANT NAME"

        result = test_instance.send(:is_transaction_continuation?, continuation_line, [ last_line ], "santander")

        expect(result).to be true
      end
    end

    context "Generic continuation logic" do
      it "identifies continuation lines for generic banks" do
        last_line = "15-01-2024  -$50.00"
        continuation_line = "  MERCHANT NAME"

        result = test_instance.send(:is_transaction_continuation?, continuation_line, [ last_line ], "generic")

        expect(result).to be true
      end

      it "returns false when filtered_lines is empty" do
        result = test_instance.send(:is_transaction_continuation?, "any line", [], "generic")
        expect(result).to be false
      end
    end
  end

  describe "#is_potential_transaction_line?" do
    context "BBVA transaction detection" do
      it "identifies valid BBVA transaction lines" do
        line = "15-jan-2024  -$50.00  MERCHANT NAME"

        result = test_instance.send(:is_potential_transaction_line?, line, "bbva")

        expect(result).to be true
      end

      it "rejects invalid BBVA transaction lines" do
        line = "15-jan-2024  MERCHANT NAME"  # Missing amount

        result = test_instance.send(:is_potential_transaction_line?, line, "bbva")

        expect(result).to be false
      end
    end

    context "Santander transaction detection" do
      it "identifies valid Santander transaction lines" do
        line = "15/01/2024  -$50.00  MERCHANT NAME"

        result = test_instance.send(:is_potential_transaction_line?, line, "santander")

        expect(result).to be true
      end
    end

    context "Generic transaction detection" do
      it "identifies valid generic transaction lines" do
        line = "15-01-2024  -$50.00  MERCHANT NAME"

        result = test_instance.send(:is_potential_transaction_line?, line, "generic")

        expect(result).to be true
      end

      it "handles various date formats" do
        line1 = "15/01/2024  -$50.00  MERCHANT"
        line2 = "15-01-2024  +$25.00  MERCHANT"

        expect(test_instance.send(:is_potential_transaction_line?, line1, "generic")).to be true
        expect(test_instance.send(:is_potential_transaction_line?, line2, "generic")).to be true
      end
    end
  end
end
