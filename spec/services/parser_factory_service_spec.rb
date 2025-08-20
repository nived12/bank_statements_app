# spec/services/parser_factory_service_spec.rb
require 'rails_helper'

RSpec.describe ParserFactoryService do
  describe '.create_parser' do
    it 'creates BBVA parser for bbva type' do
      parser = described_class.create_parser('bbva')
      expect(parser).to be_a(PdfParser::BbvaCreditCard)
    end

    it 'creates generic parser for other bank types' do
      parser = described_class.create_parser('santander')
      expect(parser).to be_a(PdfParser::Generic)
    end

    it 'creates generic parser for unknown types' do
      parser = described_class.create_parser('unknown_bank')
      expect(parser).to be_a(PdfParser::Generic)
    end
  end

  describe '.get_parser_class' do
    it 'returns BBVA parser class for bbva type' do
      parser_class = described_class.get_parser_class('bbva')
      expect(parser_class).to eq(PdfParser::BbvaCreditCard)
    end

    it 'returns generic parser class for other bank types' do
      parser_class = described_class.get_parser_class('santander')
      expect(parser_class).to eq(PdfParser::Generic)
    end
  end

  describe '.get_parsing_strategy' do
    it 'returns hybrid strategy for BBVA' do
      strategy = described_class.get_parsing_strategy('bbva')
      expect(strategy).to eq(:hybrid)
    end

    it 'returns ai_first strategy for supported banks' do
      strategy = described_class.get_parsing_strategy('santander')
      expect(strategy).to eq(:ai_first)
    end

    it 'returns parser_first strategy for generic banks' do
      strategy = described_class.get_parsing_strategy('unknown_bank')
      expect(strategy).to eq(:parser_first)
    end
  end
end
