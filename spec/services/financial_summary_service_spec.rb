# spec/services/financial_summary_service_spec.rb
require 'rails_helper'

RSpec.describe FinancialSummaryService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(statement) }
  
  before do
    # Mock the errors attribute to avoid nil issues
    allow(service).to receive(:errors).and_return(
      double('Errors', any?: false, add: nil, count: 0)
    )
  end

  describe '#create_from_extracted_data' do
    let(:financial_data) do
      {
        statement_type: 'credit',
        initial_balance: 1000.0,
        final_balance: 1200.0,
        period_dates: {
          'start' => Date.current - 30.days,
          'end' => Date.current
        },
        commission_info: { fees: 25.0, commissions: 15.0 },
        statement_type_data: { extra: 'data' }
      }
    end

    before do
      allow(StatementFinancialSummary).to receive(:create!).and_return(
        double(
          statement_file: statement,
          statement_type: 'credit',
          initial_balance: 1000.0,
          final_balance: 1200.0,
          total_commissions: 25.0,
          total_fees: 15.0
        )
      )
    end

    it 'creates a financial summary with provided data' do
      result = service.create_from_extracted_data(financial_data)

      expect(result).to be_present
      expect(StatementFinancialSummary).to have_received(:create!).with(
        hash_including(
          statement_file: statement,
          statement_type: 'credit',
          initial_balance: 1000.0,
          final_balance: 1200.0
        )
      )
    end

    context 'with missing data' do
      let(:financial_data) { {} }

      it 'creates summary with defaults' do
        result = service.create_from_extracted_data(financial_data)

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            statement_type: 'savings',
            initial_balance: 0.0,
            final_balance: 0.0
          )
        )
      end
    end

    context 'with invalid period dates (end before start)' do
      let(:financial_data) do
        {
          period_dates: {
            'start' => Date.current,
            'end' => Date.current - 5.days
          }
        }
      end

      it 'uses fallback dates' do
        result = service.create_from_extracted_data(financial_data)

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            statement_period_start: statement.created_at.to_date - 30.days,
            statement_period_end: statement.created_at.to_date
          )
        )
      end
    end

    context 'with same-day period dates' do
      let(:financial_data) do
        {
          period_dates: {
            'start' => Date.current,
            'end' => Date.current
          }
        }
      end

      it 'creates summary with same-day period' do
        result = service.create_from_extracted_data(financial_data)

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            statement_period_start: Date.current,
            statement_period_end: Date.current
          )
        )
      end
    end

    context 'when creation fails' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_raise(StandardError, 'Database error')
        allow(service).to receive(:handle_financial_summary_error)
      end

      it 'handles error and returns nil' do
        result = service.create_from_extracted_data(financial_data)

        expect(service).to have_received(:handle_financial_summary_error)
        expect(result).to be_nil
      end
    end
  end

  describe '#create_from_ai_data' do
    let(:summary_data) do
      {
        'amount' => 500.0,
        'description' => 'Opening balance',
        'date' => Date.current - 1.day,
        'details' => { 'source' => 'ai' },
        'raw_text' => 'Balance: $500.00'
      }
    end

    before do
      allow(StatementFinancialSummary).to receive(:create!).and_return(
        double(
          statement_file: statement,
          initial_balance: 500.0,
          final_balance: 0.0,
          total_commissions: 0.0,
          total_fees: 0.0,
          statement_type_data: { 'ai_extracted_type' => 'opening_balance' }
        )
      )
    end

    it 'creates AI financial summary' do
      result = service.create_from_ai_data(summary_data, 'opening_balance')

      expect(result).to be_present
      expect(StatementFinancialSummary).to have_received(:create!).with(
        hash_including(
          initial_balance: 500.0,
          final_balance: 0.0
        )
      )
    end

    context 'for closing balance' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_return(
          double(
            statement_file: statement,
            initial_balance: 0.0,
            final_balance: 500.0,
            total_commissions: 0.0,
            total_fees: 0.0
          )
        )
      end

      it 'sets final_balance instead of initial_balance' do
        result = service.create_from_ai_data(summary_data, 'closing_balance')

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            initial_balance: 0.0,
            final_balance: 500.0
          )
        )
      end
    end

    context 'for fee type' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_return(
          double(
            statement_file: statement,
            initial_balance: 0.0,
            final_balance: 0.0,
            total_commissions: 500.0,
            total_fees: 0.0
          )
        )
      end

      it 'sets total_fees' do
        result = service.create_from_ai_data(summary_data, 'fee')

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            total_commissions: 0.0,
            total_fees: 500.0
          )
        )
      end
    end

    context 'when creation fails' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_raise(StandardError, 'Database error')
        allow(service).to receive(:handle_financial_summary_error)
      end

      it 'handles error and returns nil' do
        result = service.create_from_ai_data(summary_data, 'opening_balance')

        expect(service).to have_received(:handle_financial_summary_error)
        expect(result).to be_nil
      end
    end
  end



  describe '#determine_statement_type' do
    context 'with credit account type' do
      before do
        allow(bank_account).to receive(:account_type).and_return('credit')
      end

      it 'returns credit' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('credit')
      end
    end

    context 'with savings account type' do
      before do
        allow(bank_account).to receive(:account_type).and_return('savings')
      end

      it 'returns savings' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('savings')
      end
    end

    context 'with unknown account type' do
      before do
        allow(bank_account).to receive(:account_type).and_return('unknown')
      end

      it 'defaults to savings' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('savings')
      end
    end
  end
end
