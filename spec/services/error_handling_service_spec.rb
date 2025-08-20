# spec/services/error_handling_service_spec.rb
require 'rails_helper'

RSpec.describe ErrorHandlingService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:error) { StandardError.new('Test error message').tap { |e| e.set_backtrace([ 'line1', 'line2' ]) } }

  describe '.handle_statement_error' do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it 'updates statement with error status' do
      described_class.handle_statement_error(statement, error)

      expect(statement.status).to eq('error')
      expect(statement.error_message).to include('Test error message')
      expect(statement.processed_at).to be_present
    end

    it 'logs the error with statement ID' do
      described_class.handle_statement_error(statement, error)

      expect(Rails.logger).to have_received(:error)
        .with("StatementIngestJob failed for statement #{statement.id}: Test error message")
    end

    it 'logs the error backtrace' do
      described_class.handle_statement_error(statement, error)

      expect(Rails.logger).to have_received(:error).with("line1\nline2")
    end
  end

  describe '.handle_pii_error' do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it 'updates statement with PII error status' do
      described_class.handle_pii_error(statement, error)

      expect(statement.status).to eq('error')
      expect(statement.error_message).to include('PII redaction failed: Test error message')
      expect(statement.processed_at).to be_present
    end

    it 'logs the PII error' do
      described_class.handle_pii_error(statement, error)

      expect(Rails.logger).to have_received(:error)
        .with('[PII] Redaction failed: Test error message')
    end
  end

  describe '.handle_financial_summary_error' do
    let(:financial_data) { { balance: 1000, type: 'credit' } }

    before do
      allow(Rails.logger).to receive(:error)
    end

    context 'with financial data' do
      it 'logs the error and financial data' do
        described_class.handle_financial_summary_error(error, financial_data)

        expect(Rails.logger).to have_received(:error)
          .with('Failed to create financial summary: Test error message')
        expect(Rails.logger).to have_received(:error)
          .with("Financial data: #{financial_data.inspect}")
      end
    end

    context 'without financial data' do
      it 'logs only the error' do
        described_class.handle_financial_summary_error(error)

        expect(Rails.logger).to have_received(:error)
          .with('Failed to create financial summary: Test error message')
        expect(Rails.logger).not_to have_received(:error)
          .with(/Financial data:/)
      end
    end
  end

  describe '.handle_ai_financial_summary_error' do
    before do
      allow(Rails.logger).to receive(:error)
    end

    it 'logs the AI financial summary error' do
      described_class.handle_ai_financial_summary_error(error)

      expect(Rails.logger).to have_received(:error)
        .with('Failed to create AI financial summary: Test error message')
    end
  end
end
