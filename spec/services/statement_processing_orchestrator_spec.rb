# spec/services/statement_processing_orchestrator_spec.rb
require 'rails_helper'

RSpec.describe StatementProcessingOrchestrator do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  
  before do
    # Mock the statement to avoid AI processing
    allow(statement).to receive(:ai_enabled?).and_return(false)
    
    # Mock the bank_account parsing_strategy method
    allow(bank_account).to receive(:parsing_strategy).and_return(:hybrid)
    
    # Mock the concern methods on the class since we'll be calling the class method
    allow_any_instance_of(described_class).to receive(:create_temp_file).and_return(double(path: '/tmp/test.pdf'))
    allow_any_instance_of(described_class).to receive(:cleanup_temp_file)
    allow_any_instance_of(described_class).to receive(:extract_and_process_text).and_return({
      text: 'sample text',
      filtered_text: 'filtered text',
      text_chunks: ['chunk1'],
      financial_data: {},
      source: 'text'
    })
    allow_any_instance_of(described_class).to receive(:pii_redaction_enabled?).and_return(false)
    
    # Mock the errors attribute to avoid nil issues
    allow_any_instance_of(described_class).to receive(:errors).and_return(
      double('Errors', any?: false, add: nil, count: 0)
    )

    allow(StatementParserService).to receive(:new).and_return(double(
      parse_with_deterministic_parser: { 'transactions' => [], 'financial_summaries' => [] },
      parse_with_ai: { 'transactions' => [], 'financial_summaries' => [] },
      parse_with_ai_enhancement: { 'transactions' => [], 'financial_summaries' => [] },
      merge_ai_categorization_with_parser_transactions: { 'transactions' => [], 'financial_summaries' => [] }
    ))
    allow(Transactions::Importer).to receive(:call)
    allow(FinancialSummaryService).to receive(:new).and_return(double(
      create_from_extracted_data: nil,
      create_from_parsed_data: 0
    ))
  end

  describe '.process' do
    it 'successfully processes a statement' do
      result = described_class.process(statement.id)

      expect(result.success?).to be true
      expect(statement.reload.status).to eq('parsed')
      expect(statement.parsed_json).to be_present
      expect(statement.processed_at).to be_present
    end

    it 'handles text extraction failure gracefully' do
      allow_any_instance_of(described_class).to receive(:extract_and_process_text).and_return(nil)

      result = described_class.process(statement.id)

      expect(result.failure?).to be true
    end

    it 'handles errors and updates statement status' do
      allow(StatementParserService).to receive(:new).and_raise(StandardError, 'Test error')

      result = described_class.process(statement.id)

      expect(result.failure?).to be true
      expect(statement.reload.status).to eq('error')
      expect(statement.error_message).to include('Test error')
    end

    it 'ensures temp file cleanup even on error' do
      cleanup_called = false
      allow_any_instance_of(described_class).to receive(:cleanup_temp_file) { cleanup_called = true }
      allow(StatementParserService).to receive(:new).and_raise(StandardError, 'Test error')

      described_class.process(statement.id)

      expect(cleanup_called).to be true
    end
  end
end
