require 'rails_helper'

RSpec.describe TextExtractor do
  let(:valid_pdf_path) { Rails.root.join("spec/fixtures/files/sample.pdf").to_s }

  describe '.extract_text_layer' do
    context 'with a valid PDF file' do
      it 'extracts text using PDF::Reader' do
        allow(PDF::Reader).to receive(:open).and_yield(double(pages: [ double(text: "Sample PDF text") ]))

        result = described_class.extract_text_layer(valid_pdf_path)

        expect(result).to include("Sample PDF text")
      end

      it 'falls back to CombinePDF when PDF::Reader fails' do
        allow(PDF::Reader).to receive(:open).and_raise(StandardError)
        mock_pdf = double(pages: [ double(text: "CombinePDF text") ])
        allow(CombinePDF).to receive(:load).and_return(mock_pdf)

        result = described_class.extract_text_layer(valid_pdf_path)

        expect(result).to eq("CombinePDF text")
      end

      it 'returns empty string when both methods fail' do
        allow(PDF::Reader).to receive(:open).and_raise(StandardError)
        allow(CombinePDF).to receive(:load).and_raise(StandardError)

        result = described_class.extract_text_layer(valid_pdf_path)

        expect(result).to eq("")
      end

      it 'returns empty string when extracted text is empty' do
        allow(PDF::Reader).to receive(:open).and_yield(double(pages: [ double(text: "") ]))
        allow(CombinePDF).to receive(:load).and_return(double(pages: [ double(text: "") ]))

        result = described_class.extract_text_layer(valid_pdf_path)

        expect(result).to eq("")
      end
    end

    context 'with password-protected PDF' do
      it 'passes password to PDF::Reader when provided' do
        expect(PDF::Reader).to receive(:open).with(valid_pdf_path, { password: "test_password" })
          .and_yield(double(pages: [ double(text: "Protected PDF text") ]))

        result = described_class.extract_text_layer(valid_pdf_path, password: "test_password")

        expect(result).to include("Protected PDF text")
      end

      it 'raises PasswordRequiredError when PDF is encrypted and no password provided' do
        allow(PDF::Reader).to receive(:open).and_raise(PDF::Reader::EncryptedPDFError.new("encrypted"))
        allow(CombinePDF).to receive(:load).and_raise(StandardError.new("Some error"))

        expect {
          described_class.extract_text_layer(valid_pdf_path)
        }.to raise_error(TextExtractor::PasswordRequiredError)
      end

      it 'raises PasswordRequiredError when error message contains password keyword' do
        allow(PDF::Reader)
          .to receive(:open).and_raise(StandardError.new("Document is encrypted and requires a password"))
        allow(CombinePDF).to receive(:load).and_raise(StandardError.new("password required"))

        expect {
          described_class.extract_text_layer(valid_pdf_path)
        }.to raise_error(TextExtractor::PasswordRequiredError)
      end

      it 'does not pass empty options when no password provided' do
        expect(PDF::Reader).to receive(:open).with(valid_pdf_path, {})
          .and_yield(double(pages: [ double(text: "Normal PDF text") ]))

        result = described_class.extract_text_layer(valid_pdf_path)

        expect(result).to include("Normal PDF text")
      end
    end
  end

  describe '.valid_text?' do
    context 'with valid financial text' do
      it 'returns true for text with balance information' do
        text = "Saldo anterior: $1,234.56"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for text with account numbers' do
        text = "Cuenta: 1234567890"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for text with transaction keywords' do
        text = "Depósito en efectivo"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for text with currency amounts' do
        text = "Monto: $500.00"
        expect(described_class.valid_text?(text)).to be true
      end
    end

    context 'with valid date patterns' do
      it 'returns true for DD/MM/YYYY format' do
        text = "Fecha: 15/03/2024"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for YYYY-MM-DD format' do
        text = "Date: 2024-03-15"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for Spanish date format' do
        text = "15 de marzo de 2024"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true for Month DD, YYYY format' do
        text = "March 15, 2024"
        expect(described_class.valid_text?(text)).to be true
      end
    end

    context 'with invalid text' do
      it 'returns false for empty text' do
        expect(described_class.valid_text?("")).to be false
        expect(described_class.valid_text?(nil)).to be false
        expect(described_class.valid_text?("   ")).to be false
      end

      it 'returns false for text without financial or date patterns' do
        text = "This is just regular text without any financial information"
        expect(described_class.valid_text?(text)).to be false
      end

      it 'returns false for gibberish text' do
        text = "asdfghjkl qwertyuiop"
        expect(described_class.valid_text?(text)).to be false
      end
    end

    context 'with mixed content' do
      it 'returns true when both date and financial patterns are present' do
        text = "Estado de cuenta del 15/03/2024 - Saldo: $1,500.00"
        expect(described_class.valid_text?(text)).to be true
      end

      it 'returns true when only one pattern type is present' do
        text = "Transacción realizada con éxito"
        expect(described_class.valid_text?(text)).to be true
      end
    end
  end

  describe 'DATE_PATTERNS constant' do
    it 'matches various date formats' do
      dates = [
        "15/03/2024",
        "2024-03-15",
        "15 de marzo de 2024",
        "marzo 15, 2024",
        "15/3/24",
        "15-03-2024"
      ]

      dates.each do |date|
        pattern_match = described_class::DATE_PATTERNS.any? { |pattern| pattern.match?(date) }
        expect(pattern_match).to be(true), "Expected #{date} to match a date pattern"
      end
    end
  end

  describe 'FINANCIAL_PATTERNS constant' do
    it 'matches various financial patterns' do
      financial_texts = [
        "saldo: $1,234.56",
        "Balance: 1000.00",
        "Cuenta: 1234567890",
        "Account number: 9876543210",
        "Transacción exitosa",
        "Depósito en efectivo",
        "$500.00"
      ]

      financial_texts.each do |text|
        pattern_match = described_class::FINANCIAL_PATTERNS.any? { |pattern| pattern.match?(text) }
        expect(pattern_match).to be(true), "Expected '#{text}' to match a financial pattern"
      end
    end
  end
end
