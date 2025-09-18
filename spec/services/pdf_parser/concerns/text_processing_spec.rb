require 'rails_helper'
require 'bigdecimal'

RSpec.describe PdfParser::Concerns::TextProcessing do
  # Helper module for testing
  module TestHelper
    def parse_decimal(str)
      s = str.to_s.strip
      return if s.empty?

      negative = false
      if s.start_with?("(") && s.end_with?(")")
        negative = true
        s = s[1..-2]
      end
      s = s.delete(" ")

      normalized =
        if s.count(",") >= 1 && s.count(".") >= 1
          s.tr(",", "")
        elsif s.count(",") >= 1 && s.count(".") == 0
          s.tr(",", ".")
        else
          s
        end

      begin
        bd = BigDecimal(normalized)
        negative ? -bd : bd
      rescue
        nil
      end
    end
  end

  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include PdfParser::Concerns::TextProcessing
      include TestHelper
    end
  end

  let(:instance) { test_class.new }

  describe '#clean_text' do
    it 'handles encoding issues' do
      text = "PAGO DE NOMINA\xFF\xFE"
      result = instance.send(:clean_text, text)
      expect(result).to eq("PAGO DE NOMINA??")
    end

    it 'handles nil input' do
      result = instance.send(:clean_text, nil)
      expect(result).to eq("")
    end

    it 'handles empty strings' do
      result = instance.send(:clean_text, "")
      expect(result).to eq("")
    end
  end

  describe '#split_into_lines' do
    it 'splits text into lines and strips whitespace' do
      text = "Line 1\nLine 2\r\nLine 3\n\n"
      result = instance.send(:split_into_lines, text)
      expect(result).to eq([ "Line 1", "Line 2", "Line 3" ])
    end

    it 'handles empty text' do
      result = instance.send(:split_into_lines, "")
      expect(result).to eq([])
    end
  end

  describe '#clean_description' do
    it 'removes PII markers' do
      text = "PAGO DE NOMINA [PII:name:123456] APPTEGY"
      result = instance.send(:clean_description, text)
      expect(result).to eq("PAGO DE NOMINA APPTEGY")
    end

    it 'removes both bracket and angle bracket PII markers' do
      text = "PAGO DE NOMINA [PII:name:123456] ⟪PII:account:789012⟫ APPTEGY"
      result = instance.send(:clean_description, text)
      expect(result).to eq("PAGO DE NOMINA APPTEGY")
    end

    it 'normalizes whitespace' do
      text = "PAGO   DE    NOMINA    APPTEGY"
      result = instance.send(:clean_description, text)
      expect(result).to eq("PAGO DE NOMINA APPTEGY")
    end

    it 'strips leading and trailing whitespace' do
      text = "  PAGO DE NOMINA APPTEGY  "
      result = instance.send(:clean_description, text)
      expect(result).to eq("PAGO DE NOMINA APPTEGY")
    end
  end

  describe '#clean_ocr_text' do
    it 'removes OCR artifacts like brackets' do
      line = "PAGO DE NOMINA [123456] APPTEGY"
      result = instance.send(:clean_ocr_text, line)
      expect(result).to eq("PAGO DE NOMINA 123456 APPTEGY")
    end

    it 'removes multiple bracket pairs' do
      line = "[PAGO] DE [NOMINA] [123456]"
      result = instance.send(:clean_ocr_text, line)
      expect(result).to eq("PAGO DE NOMINA 123456")
    end

    it 'strips whitespace' do
      line = "  PAGO DE NOMINA [123456]  "
      result = instance.send(:clean_ocr_text, line)
      expect(result).to eq("PAGO DE NOMINA 123456")
    end
  end

  describe '#extract_amount_from_line' do
    it 'extracts single amount' do
      line = "Saldo Anterior: 1,000.00"
      result = instance.send(:extract_amount_from_line, line)
      expect(result).to eq(BigDecimal("1000.00"))
    end

    it 'extracts last amount when multiple present' do
      line = "20.00 8,788.51"
      result = instance.send(:extract_amount_from_line, line)
      expect(result).to eq(BigDecimal("8788.51"))
    end

    it 'returns nil when no amount found' do
      line = "No amount here"
      result = instance.send(:extract_amount_from_line, line)
      expect(result).to be_nil
    end
  end

  describe '#extract_number_from_line' do
    it 'extracts number from text' do
      line = "Días del Periodo: 31"
      result = instance.send(:extract_number_from_line, line)
      expect(result).to eq(31)
    end

    it 'returns nil when no number found' do
      line = "No number here"
      result = instance.send(:extract_number_from_line, line)
      expect(result).to be_nil
    end
  end
end
