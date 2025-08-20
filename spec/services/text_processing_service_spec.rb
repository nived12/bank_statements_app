# spec/services/text_processing_service_spec.rb
require 'rails_helper'

RSpec.describe TextProcessingService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(statement) }

  describe '#extract_text' do
    let(:file_path) { '/tmp/test.pdf' }

    before do
      allow(TextExtractor).to receive(:extract_text_layer).and_return('sample text layer')
      allow(TextExtractor).to receive(:valid_text?).and_return(true)
      allow(Ocr::Service).to receive(:extract_text).and_return('sample ocr text')
    end

    context 'when text layer extraction succeeds' do
      it 'returns text layer and sets source to text' do
        result = service.extract_text(file_path)

        expect(result).to eq('sample text layer')
        expect(service.source).to eq('text')
      end
    end

    context 'when text layer extraction fails but OCR succeeds' do
      before do
        allow(TextExtractor).to receive(:valid_text?).with('sample text layer').and_return(false)
        allow(TextExtractor).to receive(:valid_text?).with('sample ocr text').and_return(true)
      end

      it 'returns OCR text and sets source to ocr' do
        result = service.extract_text(file_path)

        expect(result).to eq('sample ocr text')
        expect(service.source).to eq('ocr')
      end
    end

    context 'when both text layer and OCR extraction fail' do
      before do
        allow(TextExtractor).to receive(:valid_text?).and_return(false)
      end

      it 'updates statement with error and returns nil' do
        result = service.extract_text(file_path)

        expect(result).to be_nil
        expect(statement.status).to eq('error')
        expect(statement.error_message).to include('No extractable text found')
      end
    end
  end

  describe '#filter_text' do
    let(:text) { 'sample bank statement text' }

    before do
      allow(TransactionTextFilter).to receive(:filter_for_transactions).and_return('filtered text')
    end

    it 'filters text using TransactionTextFilter' do
      result = service.filter_text(text)

      expect(TransactionTextFilter).to have_received(:filter_for_transactions)
        .with(text, bank_name: bank_account.bank_name)
      expect(result).to eq('filtered text')
    end
  end

  describe '#extract_financial_data' do
    let(:text) { 'sample bank statement text' }

    before do
      allow(TransactionTextFilter).to receive(:extract_financial_data).and_return({ balance: 1000 })
    end

    it 'extracts financial data using TransactionTextFilter' do
      result = service.extract_financial_data(text)

      expect(TransactionTextFilter).to have_received(:extract_financial_data)
        .with(text, bank_name: bank_account.bank_name)
      expect(result).to eq({ balance: 1000 })
    end
  end

  describe '#prepare_text_chunks' do
    context 'when text is short' do
      let(:text) { 'short text' }

      it 'returns text as single chunk' do
        result = service.prepare_text_chunks(text)

        expect(result).to eq(['short text'])
      end
    end

    context 'when text is long' do
      let(:text) { 'a' * 10000 }

      before do
        allow(ConfigurationService).to receive(:text_chunk_size).and_return(8000)
      end

      it 'chunks text into multiple parts' do
        result = service.prepare_text_chunks(text)

        expect(result.length).to be > 1
        expect(result.first.length).to eq(8000)
      end
    end

    context 'with custom max_length' do
      let(:text) { 'a' * 5000 }

      it 'uses custom max_length for chunking' do
        result = service.prepare_text_chunks(text, max_length: 2000)

        expect(result.length).to be > 1
        expect(result.first.length).to eq(2000)
      end
    end
  end

  describe '#prepare_transaction_text_for_ai' do
    let(:text) { "Some text\n12-jan-2024 EXPENSE -$100.00\n13-jan-2024 INCOME +$50.00\nMore text" }

    context 'with BBVA bank account' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('bbva')
        allow(ConfigurationService).to receive(:transaction_text_chunk_size).and_return(4000)
      end

      it 'extracts only transaction lines' do
        result = service.prepare_transaction_text_for_ai(text)

        expect(result).to be_an(Array)
        expect(result.first).to include('12-jan-2024 EXPENSE -$100.00')
        expect(result.first).to include('13-jan-2024 INCOME +$50.00')
        expect(result.first).not_to include('Some text')
        expect(result.first).not_to include('More text')
      end
    end

    context 'with non-BBVA bank account' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('santander')
        allow(ConfigurationService).to receive(:text_chunk_size).and_return(8000)
      end

      it 'returns text as chunks without filtering' do
        result = service.prepare_transaction_text_for_ai(text)

        expect(result).to eq([text])
      end
    end
  end
end
