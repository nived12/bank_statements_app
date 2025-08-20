# spec/services/financial_summary_service_spec.rb
require 'rails_helper'

RSpec.describe FinancialSummaryService do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(statement) }

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

    context 'with invalid period dates' do
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

    context 'when creation fails' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_raise(StandardError, 'Database error')
        allow(ErrorHandlingService).to receive(:handle_financial_summary_error)
      end

      it 'handles error and returns nil' do
        result = service.create_from_extracted_data(financial_data)

        expect(ErrorHandlingService).to have_received(:handle_financial_summary_error)
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

      it 'sets total_commissions' do
        result = service.create_from_ai_data(summary_data, 'fee')

        expect(result).to be_present
        expect(StatementFinancialSummary).to have_received(:create!).with(
          hash_including(
            total_commissions: 500.0,
            total_fees: 0.0
          )
        )
      end
    end

    context 'when creation fails' do
      before do
        allow(StatementFinancialSummary).to receive(:create!).and_raise(StandardError, 'Database error')
        allow(ErrorHandlingService).to receive(:handle_ai_financial_summary_error)
      end

      it 'handles error and returns nil' do
        result = service.create_from_ai_data(summary_data, 'opening_balance')

        expect(ErrorHandlingService).to have_received(:handle_ai_financial_summary_error)
        expect(result).to be_nil
      end
    end
  end

  describe '#create_from_parsed_data' do
    let(:parsed_data) do
      {
        'financial_summaries' => [
          {
            'type' => 'balance',
            'description' => 'opening balance inicial',
            'amount' => 1000.0,
            'date' => Date.current - 30.days
          },
          {
            'type' => 'fee',
            'description' => 'Monthly fee',
            'amount' => 25.0,
            'date' => Date.current - 15.days
          }
        ]
      }
    end

    before do
      allow(service).to receive(:create_from_ai_data).and_return(double)
    end

    it 'creates summaries for each item in parsed data' do
      result = service.create_from_parsed_data(parsed_data)

      expect(service).to have_received(:create_from_ai_data).twice
      expect(result).to eq(2)
    end

    context 'with balance types' do
      it 'correctly identifies opening balance' do
        service.create_from_parsed_data(parsed_data)

        expect(service).to have_received(:create_from_ai_data)
          .with(parsed_data['financial_summaries'][0], 'opening_balance')
      end
    end

    context 'with no financial summaries' do
      let(:parsed_data) { {} }

      it 'returns without processing' do
        result = service.create_from_parsed_data(parsed_data)

        expect(result).to be_nil
        expect(service).not_to have_received(:create_from_ai_data)
      end
    end
  end

  describe '#determine_statement_type' do
    context 'with credit parser type' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('credit')
      end

      it 'returns credit' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('credit')
      end
    end

    context 'with savings parser type' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('savings')
      end

      it 'returns savings' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('savings')
      end
    end

    context 'with unknown parser type' do
      before do
        allow(bank_account).to receive(:parser_type).and_return('unknown')
      end

      it 'defaults to savings' do
        result = service.send(:determine_statement_type)

        expect(result).to eq('savings')
      end
    end
  end
end
