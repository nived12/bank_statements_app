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

    end
  end
end
