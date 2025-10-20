# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transactions::CreateService do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before do
    Current.user = user
  end

  after do
    Current.reset
  end

  describe '#call' do
    context 'with valid parameters' do
      let(:valid_params) do
        ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test transaction',
          amount: 100.50,
          transaction_type: 'income',
          category_id: category.id,
          merchant: 'Test Merchant',
          reference: 'REF123'
        }).permit!
      end

      it 'creates a transaction successfully' do
        result = described_class.call(valid_params)

        expect(result).to be_success
        expect(result.payload).to be_a(Transaction)
        expect(result.payload.user).to eq(user)
        expect(result.payload.bank_account).to eq(bank_account)
        expect(result.payload.description).to eq('Test transaction')
        expect(result.payload.amount).to eq(100.50)
        expect(result.payload.transaction_type).to eq('income')
        expect(result.payload.category).to eq(category)
        expect(result.payload.merchant).to eq('Test Merchant')
        expect(result.payload.reference).to eq('REF123')
        expect(result.payload.statement_file).to be_nil
      end

      it 'creates a transaction without optional fields' do
        minimal_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Minimal transaction',
          amount: 50.00,
          transaction_type: 'variable_expense'
        }).permit!

        result = described_class.call(minimal_params)

        expect(result).to be_success
        expect(result.payload.description).to eq('Minimal transaction')
        expect(result.payload.category).to be_nil
        expect(result.payload.merchant).to be_nil
        expect(result.payload.reference).to be_nil
      end
    end

    context 'with invalid parameters' do
      it 'fails when required fields are missing' do
        invalid_params = ActionController::Parameters.new({ description: 'Incomplete transaction' }).permit!

        result = described_class.call(invalid_params)

        expect(result).to be_failure
        expect(result.errors).not_to be_empty
      end

      it 'fails when bank_account_id is invalid' do
        invalid_params = ActionController::Parameters.new({
          bank_account_id: 99999,
          date: Date.current,
          description: 'Test transaction',
          amount: 100.50,
          transaction_type: 'income'
        }).permit!

        result = described_class.call(invalid_params)

        expect(result).to be_failure
        expect(result.errors).not_to be_empty
      end

      it 'allows negative amounts for expenses' do
        expense_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test expense',
          amount: -100.50,
          transaction_type: 'variable_expense'
        }).permit!

        result = described_class.call(expense_params)

        expect(result).to be_success
        expect(result.payload.amount).to eq(-100.50)
      end

      it 'allows positive amounts for income' do
        income_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test income',
          amount: 100.50,
          transaction_type: 'income'
        }).permit!

        result = described_class.call(income_params)

        expect(result).to be_success
        expect(result.payload.amount).to eq(100.50)
      end

      it 'fails when amount is zero' do
        invalid_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test transaction',
          amount: 0,
          transaction_type: 'income'
        }).permit!

        result = described_class.call(invalid_params)

        expect(result).to be_failure
        expect(result.errors).not_to be_empty
      end
    end

    context 'with manual goal linking' do
      let(:goal) do
        create(:goal,
               user: user,
               name: "Savings Goal",
               target_amount: 5000,
               current_amount: 0,
               start_date: 1.month.ago.to_date,
               deadline: 6.months.from_now.to_date,
               goal_calculation_settings: {
                 "income" => "positive",
                 "expense" => "ignore",
                 "transfer_in" => "positive",
                 "transfer_out" => "ignore"
               })
      end

      context 'when goal_id is provided' do
        let(:params_with_goal) do
          ActionController::Parameters.new({
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Test transaction',
            amount: 1000,
            transaction_type: 'income',
            category_id: category.id,
            goal_ids: [goal.id]
          }).permit!
        end

        it 'creates transaction and links it to goal' do
          result = described_class.call(params_with_goal)

          expect(result).to be_success
          expect(result.payload.goal_transactions.count).to eq(1)
        end

        it 'creates GoalTransaction with "Manually linked" notes' do
          result = described_class.call(params_with_goal)

          goal_transaction = result.payload.goal_transactions.first
          expect(goal_transaction.notes).to eq("Manually linked")
        end

        it 'calculates amount based on goal_calculation_settings' do
          result = described_class.call(params_with_goal)

          goal_transaction = result.payload.goal_transactions.first
          expect(goal_transaction.amount_applied).to eq(1000)
        end

        it 'updates goal current_amount' do
          expect {
            described_class.call(params_with_goal)
            goal.reload
          }.to change { goal.current_amount }.from(0).to(1000)
        end

        context 'when transaction type is set to ignore in goal settings' do
          let(:params_with_ignored_type) do
            ActionController::Parameters.new({
              bank_account_id: bank_account.id,
              date: Date.current,
              description: 'Test expense',
              amount: 500,
              transaction_type: 'variable_expense',
              category_id: category.id,
              goal_ids: [goal.id]
            }).permit!
          end

          it 'creates transaction but does not link to goal' do
            result = described_class.call(params_with_ignored_type)

            expect(result).to be_success
            expect(result.payload.goal_transactions).to be_empty
          end

          it 'logs a warning' do
            expect(Rails.logger).to receive(:warn).with(/transaction type variable_expense is set to 'ignore'/)
            described_class.call(params_with_ignored_type)
          end
        end

        context 'when goal is not active' do
          before { goal.update(status: "completed") }

          it 'creates transaction but does not link to goal' do
            result = described_class.call(params_with_goal)

            expect(result).to be_success
            expect(result.payload.goal_transactions).to be_empty
          end
        end

        context 'when goal_id is invalid' do
          let(:params_with_invalid_goal) do
            ActionController::Parameters.new({
              bank_account_id: bank_account.id,
              date: Date.current,
              description: 'Test transaction',
              amount: 1000,
              transaction_type: 'income',
              category_id: category.id,
              goal_ids: [99999]
            }).permit!
          end

          it 'creates transaction but does not link' do
            result = described_class.call(params_with_invalid_goal)

            expect(result).to be_success
            expect(result.payload.goal_transactions).to be_empty
          end
        end
      end

      context 'when goal_id is not provided' do
        let(:params_without_goal) do
          ActionController::Parameters.new({
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Test transaction',
            amount: 1000,
            transaction_type: 'income',
            category_id: category.id
          }).permit!
        end

        it 'creates transaction without manual linking' do
          result = described_class.call(params_without_goal)

          expect(result).to be_success
          manually_linked = result.payload.goal_transactions.where(notes: "Manually linked")
          expect(manually_linked).to be_empty
        end
      end
    end
  end
end
