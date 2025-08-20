# spec/services/statement_processing_orchestrator_spec.rb
require 'rails_helper'

RSpec.describe StatementProcessingOrchestrator do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:text_processing_service) { instance_double(TextProcessingService) }
  let(:orchestrator) { described_class.new(statement) }

  before do
    allow(FileHandlingService).to receive(:create_temp_file).and_return(double(path: '/tmp/test.pdf'))
    allow(FileHandlingService).to receive(:cleanup_temp_file)
    allow(TextProcessingService).to receive(:new).and_return(text_processing_service)

    # Default successful behavior
    allow(text_processing_service).to receive(:extract_text).and_return('sample text')
    allow(text_processing_service).to receive(:extract_financial_data).and_return({})
    allow(text_processing_service).to receive(:filter_text).and_return('filtered text')
    allow(text_processing_service).to receive(:prepare_text_chunks).and_return([ 'chunk1' ])
    allow(text_processing_service).to receive(:source).and_return('text')

    allow(StatementParserService).to receive(:new).and_return(double(
      parse: { 'transactions' => [], 'financial_summaries' => [] }
    ))
    allow(Transactions::Importer).to receive(:call)
    allow(FinancialSummaryService).to receive(:new).and_return(double(
      create_from_extracted_data: nil,
      create_from_parsed_data: 0
    ))
    allow(ConfigurationService).to receive(:pii_redaction_enabled?).and_return(false)
  end

  describe '#process' do
    it 'successfully processes a statement' do
      result = orchestrator.process

      expect(result).to be true
      expect(statement.status).to eq('parsed')
      expect(statement.parsed_json).to be_present
      expect(statement.processed_at).to be_present
    end

    it 'handles text extraction failure gracefully' do
      allow(text_processing_service).to receive(:extract_text).and_return(nil)

      result = orchestrator.process

      expect(result).to be false
    end

    it 'handles errors and updates statement status' do
      allow(StatementParserService).to receive(:new).and_raise(StandardError, 'Test error')

      result = orchestrator.process

      expect(result).to be false
      expect(statement.status).to eq('error')
      expect(statement.error_message).to include('Test error')
    end

    it 'ensures temp file cleanup even on error' do
      allow(StatementParserService).to receive(:new).and_raise(StandardError, 'Test error')

      orchestrator.process

      expect(FileHandlingService).to have_received(:cleanup_temp_file)
    end
  end
end
