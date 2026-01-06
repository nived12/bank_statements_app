require 'rails_helper'

RSpec.describe StatementFinancialSummary, type: :model do
  let(:statement_file) { create(:statement_file) }

  describe 'validations' do
    subject { build(:statement_financial_summary, statement_file: statement_file) }

    it 'is valid with all attributes' do
      expect(subject).to be_valid
    end

    it 'requires statement_type' do
      subject.statement_type = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:statement_type]).to include("no puede estar en blanco")
    end

    it 'requires initial_balance' do
      subject.initial_balance = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:initial_balance]).to include("no puede estar en blanco")
    end

    it 'requires final_balance' do
      subject.final_balance = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:final_balance]).to include("no puede estar en blanco")
    end

    it 'requires statement_period_start' do
      subject.statement_period_start = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:statement_period_start]).to include("no puede estar en blanco")
    end

    it 'requires statement_period_end' do
      subject.statement_period_end = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:statement_period_end]).to include("no puede estar en blanco")
    end

    it 'requires days_in_period' do
      subject.days_in_period = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:days_in_period]).to include("no puede estar en blanco")
    end

    it 'requires initial_balance to be numeric' do
      subject.initial_balance = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:initial_balance]).to include("no es un número")
    end

    it 'requires final_balance to be numeric' do
      subject.final_balance = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:final_balance]).to include("no es un número")
    end

    it 'requires days_in_period to be greater than 0' do
      subject.days_in_period = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:days_in_period]).to include("debe ser mayor que 0")
    end
  end

  describe 'period validation' do
    context 'when end date is before start date' do
      subject do
        build(
          :statement_financial_summary,
          statement_file: statement_file,
          statement_period_start: Date.current,
          statement_period_end: Date.current - 1.day
        )
      end

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors[:statement_period_end]).to include('must not be before start date')
      end
    end

    context 'when end date equals start date (same-day period)' do
      subject do
        build(
          :statement_financial_summary,
          statement_file: statement_file,
          statement_period_start: Date.current,
          statement_period_end: Date.current
        )
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when end date is after start date' do
      subject do
        build(
          :statement_financial_summary,
          statement_file: statement_file,
          statement_period_start: Date.current,
          statement_period_end: Date.current + 1.day
        )
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end

  describe 'enums' do
    it 'defines statement_type enum' do
      expect(described_class.statement_types).to include(
        'savings' => 'savings',
        'credit' => 'credit',
        'payroll' => 'payroll'
      )
    end
  end

  describe 'associations' do
    it 'belongs to a statement_file' do
      summary = build(:statement_financial_summary, statement_file: statement_file)
      expect(summary.statement_file).to eq(statement_file)
    end
  end

  describe 'scopes' do
    let!(:summary1) do
      create(
        :statement_financial_summary,
        statement_file: statement_file,
        statement_period_start: Date.current - 2.days,
        statement_period_end: Date.current
      )
    end

    let!(:summary2) do
      create(
        :statement_financial_summary,
        statement_file: statement_file,
        statement_period_start: Date.current + 3.days,
        statement_period_end: Date.current + 6.days
      )
    end

    describe '.by_period' do
      it 'returns summaries within the specified period' do
        # The scope checks if statement_period_start is within the range
        result = described_class.by_period(Date.current - 3.days, Date.current + 2.days)
        expect(result).to include(summary1)
        expect(result).not_to include(summary2)
      end
    end
  end

  describe 'instance methods' do
    let(:summary) do
      create(
        :statement_financial_summary,
        statement_file: statement_file,
        statement_period_start: Date.current,
        statement_period_end: Date.current + 2.days,
        initial_balance: 1000.0,
        final_balance: 1200.0
      )
    end

    describe '#net_movement' do
      it 'calculates the difference between final and initial balance' do
        expect(summary.net_movement).to eq(200.0)
      end
    end


    describe '#total_deposits' do
      context 'for savings account' do
        before { summary.update!(statement_type: 'savings') }

        it 'returns total deposits from statement_type_data' do
          summary.statement_type_data = { 'total_deposits' => 500.0 }
          expect(summary.total_deposits).to eq(500.0)
        end

        it 'returns 0 when no deposits data' do
          expect(summary.total_deposits).to eq(0)
        end
      end

      context 'for credit account' do
        before { summary.update!(statement_type: 'credit') }

        it 'returns total payments from statement_type_data' do
          summary.statement_type_data = { 'total_payments' => 300.0 }
          expect(summary.total_deposits).to eq(300.0)
        end
      end
    end

    describe '#total_withdrawals' do
      context 'for savings account' do
        before { summary.update!(statement_type: 'savings') }

        it 'returns total withdrawals from statement_type_data' do
          summary.statement_type_data = { 'total_withdrawals' => 200.0 }
          expect(summary.total_withdrawals).to eq(200.0)
        end
      end

            context 'for credit account' do
        before { summary.update!(statement_type: 'credit') }

        it 'returns total charges from statement_type_data' do
          summary.statement_type_data = { 'total_charges' => 150.0 }
          expect(summary.total_withdrawals).to eq(150.0)
        end
      end
  end
  end
end
