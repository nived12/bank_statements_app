# spec/services/statement_parser_service_spec.rb
require 'rails_helper'

RSpec.describe StatementParserService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(statement) }
  let(:text_chunks) { [ 'chunk1', 'chunk2' ] }
  let(:masked_text) { 'masked text content' }
  let(:text) { 'original text content' }

  before do
    allow(ConfigurationService).to receive(:ai_api_available?).and_return(true)
    allow(user).to receive(:categories).and_return([])
  end

  describe '#parse' do
    context 'with hybrid strategy' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('bbva')
        allow(ParserFactoryService).to receive(:get_parsing_strategy).and_return(:hybrid)
        allow(service).to receive(:parse_with_hybrid_approach).and_return({ 'transactions' => [] })
      end

      it 'calls hybrid approach' do
        service.parse(text_chunks, masked_text, text)

        expect(service).to have_received(:parse_with_hybrid_approach)
          .with(text_chunks, masked_text, text)
      end
    end

    context 'with AI-first strategy' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('santander')
        allow(ParserFactoryService).to receive(:get_parsing_strategy).and_return(:ai_first)
        allow(service).to receive(:parse_with_ai_or_fallback).and_return({ 'transactions' => [] })
      end

      it 'calls AI-first approach' do
        service.parse(text_chunks, masked_text, text)

        expect(service).to have_received(:parse_with_ai_or_fallback)
          .with(text_chunks, masked_text, text)
      end
    end

    context 'with parser-first strategy' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('generic')
        allow(ParserFactoryService).to receive(:get_parsing_strategy).and_return(:parser_first)
        allow(service).to receive(:parse_with_parser_or_fallback).and_return({ 'transactions' => [] })
      end

      it 'calls parser-first approach' do
        service.parse(text_chunks, masked_text, text)

        expect(service).to have_received(:parse_with_parser_or_fallback)
          .with(text_chunks, masked_text, text)
      end
    end
  end

  describe '#parse_with_hybrid_approach' do
    let(:parser_result) { { 'transactions' => [ { 'id' => 1 } ] } }
    let(:ai_result) { { 'transactions' => [ { 'id' => 1, 'category' => 'food' } ] } }

    before do
      allow(service).to receive(:parse_with_deterministic_parser).and_return(parser_result)
      allow(service).to receive(:parse_with_ai).and_return(ai_result)
      allow(service).to receive(:merge_ai_categorization_with_parser_transactions)
        .and_return({ 'transactions' => [] })
    end

    context 'when parser succeeds and AI succeeds' do
      it 'merges results and sets extraction source' do
        result = service.send(:parse_with_hybrid_approach, text_chunks, masked_text, text)

        expect(service).to have_received(:merge_ai_categorization_with_parser_transactions)
          .with(parser_result, ai_result)
      end
    end

    context 'when parser succeeds but AI fails' do
      before do
        allow(service).to receive(:parse_with_ai).and_return(nil)
      end

      it 'uses parser result with basic categorization' do
        result = service.send(:parse_with_hybrid_approach, text_chunks, masked_text, text)

        expect(result).to eq(parser_result)
        expect(result['extraction_source']).to eq('parser_with_basic_categorization')
      end
    end

    context 'when parser fails' do
      before do
        allow(service).to receive(:parse_with_deterministic_parser).and_return({ 'transactions' => [] })
        allow(service).to receive(:parse_with_ai).and_return(ai_result)
      end

      it 'falls back to AI only' do
        result = service.send(:parse_with_hybrid_approach, text_chunks, masked_text, text)

        expect(result).to eq(ai_result)
        expect(result['extraction_source']).to eq('ai_parser_fallback')
      end
    end
  end

  describe '#parse_with_ai' do
    let(:user_categories) { [] }

    before do
      allow(user).to receive(:categories).and_return(user_categories)
    end

    context 'when AI API is available' do
      before do
        allow(ConfigurationService).to receive(:ai_api_available?).and_return(true)
      end

      context 'with single chunk' do
        let(:text_chunks) { [ 'single chunk' ] }

        before do
          allow(Ai::PostProcessor).to receive(:new).and_return(
            double(call: { 'transactions' => [ { 'id' => 1 } ] })
          )
        end

        it 'processes single chunk with AI' do
          result = service.send(:parse_with_ai, text_chunks, masked_text)

          expect(result).to be_present
          expect(result['transactions']).to be_present
        end
      end

      context 'with multiple chunks' do
        before do
          allow(service).to receive(:process_multiple_chunks).and_return({ 'transactions' => [] })
        end

        it 'processes multiple chunks' do
          result = service.send(:parse_with_ai, text_chunks, masked_text)

          expect(service).to have_received(:process_multiple_chunks)
            .with(text_chunks, user_categories, masked_text)
        end
      end
    end

    context 'when AI API is not available' do
      before do
        allow(ConfigurationService).to receive(:ai_api_available?).and_return(false)
      end

      it 'returns nil' do
        result = service.send(:parse_with_ai, text_chunks, masked_text)

        expect(result).to be_nil
      end
    end

    context 'with retry logic' do
      before do
        allow(ConfigurationService).to receive(:ai_max_retries).and_return(2)
        allow(ConfigurationService).to receive(:ai_retry_delay_base).and_return(2)
      end

      it 'retries on failure and succeeds' do
        # Mock the Ai::PostProcessor to fail once then succeed
        mock_processor = double('Ai::PostProcessor')
        allow(Ai::PostProcessor).to receive(:new).and_return(mock_processor)

        call_count = 0
        allow(mock_processor).to receive(:call) do
          call_count += 1
          if call_count == 1
            raise StandardError, 'First attempt failed'
          else
            { 'transactions' => [ { 'id' => 1 } ] }
          end
        end

        # Mock sleep to avoid actual delays in tests
        allow(service).to receive(:sleep)

        result = service.send(:parse_with_ai, text_chunks, masked_text)

        expect(result).to be_present
        expect(call_count).to eq(3) # 1 initial attempt + 2 retries = 3 total calls
        expect(service).to have_received(:sleep).with(2) # First retry delay: 2^1 = 2
      end
    end
  end

  describe '#parse_with_deterministic_parser' do
    let(:parser_type) { 'bbva' }
    let(:parser_class) { PdfParser::BbvaCreditCard }

    before do
      allow(bank_account).to receive(:parser_type).and_return(parser_type)
      allow(ParserFactoryService).to receive(:get_parser_class).and_return(parser_class)
      allow(parser_class).to receive(:new).and_return(double(parse: { 'transactions' => [] }))
    end

    it 'creates parser and parses text' do
      result = service.send(:parse_with_deterministic_parser, text)

      expect(ParserFactoryService).to have_received(:get_parser_class).with(parser_type)
      expect(result).to be_present
    end

    context 'when parser fails' do
      before do
        allow(parser_class).to receive(:new).and_raise(StandardError, 'Parser error')
        allow(service).to receive(:parse_with_generic_parser).and_return({ 'transactions' => [] })
      end

      it 'falls back to generic parser' do
        result = service.send(:parse_with_deterministic_parser, text)

        expect(service).to have_received(:parse_with_generic_parser).with(text)
        expect(result).to be_present
      end
    end
  end

  describe '#merge_ai_categorization_with_parser_transactions' do
    let(:parser_result) do
      {
        'transactions' => [
          { 'date' => '2024-01-01', 'amount' => -100.0, 'description' => 'Restaurant' }
        ],
        'opening_balance' => 1000.0,
        'closing_balance' => 900.0
      }
    end

    let(:ai_result) do
      {
        'transactions' => [
          { 'date' => '2024-01-01', 'amount' => -100.0, 'description' => 'Restaurant', 'category' => 'food' }
        ]
      }
    end

    it 'merges AI categorization with parser transactions' do
      result = service.send(:merge_ai_categorization_with_parser_transactions, parser_result, ai_result)

      expect(result['opening_balance']).to eq(1000.0)
      expect(result['closing_balance']).to eq(900.0)
      expect(result['transactions'].first['category']).to eq('food')
    end
  end

  describe '#create_transaction_key' do
    let(:transaction) do
      {
        'date' => '2024-01-01',
        'amount' => -100.0,
        'description' => 'Restaurant ABC'
      }
    end

    it 'creates multiple key variations for matching' do
      keys = service.send(:create_transaction_key, transaction)

      expect(keys).to be_an(Array)
      expect(keys.length).to eq(2)
      expect(keys.first).to include('2024-01-01')
      expect(keys.first).to include('100.0')
      expect(keys.first).to include('restaurant')
    end
  end

  describe '#determine_extraction_source' do
    context 'when result has OCR source' do
      let(:result) { { 'extraction_source' => 'ocr' } }

      it 'preserves OCR source' do
        source = service.send(:determine_extraction_source, result, 'default_source')

        expect(source).to eq('ocr')
      end
    end

    context 'when result has no extraction source' do
      let(:result) { {} }

      it 'uses default source' do
        source = service.send(:determine_extraction_source, result, 'default_source')

        expect(source).to eq('default_source')
      end
    end
  end
end
