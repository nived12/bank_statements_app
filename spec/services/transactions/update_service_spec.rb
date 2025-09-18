# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transactions::UpdateService do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: nil, merchant: nil, reference: nil) }

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
          description: 'Updated transaction',
          amount: 200.75,
          transaction_type: 'income',
          category_id: category.id,
          merchant: 'Updated Merchant',
          reference: 'UPD123'
        }).permit!
      end

      it 'updates a transaction successfully' do
        result = described_class.call(transaction.id, valid_params)

        expect(result).to be_success
        expect(result.payload).to eq(transaction.reload)
        expect(transaction.description).to eq('Updated transaction')
        expect(transaction.amount).to eq(200.75)
        expect(transaction.merchant).to eq('Updated Merchant')
        expect(transaction.reference).to eq('UPD123')
      end

      it 'updates with minimal parameters' do
        minimal_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Minimal update',
          amount: 50.00,
          transaction_type: 'variable_expense'
        }).permit!

        result = described_class.call(transaction.id, minimal_params)

        expect(result).to be_success
        expect(transaction.reload.description).to eq('Minimal update')
        expect(transaction.category).to be_nil
        expect(transaction.merchant).to be_nil
        expect(transaction.reference).to be_nil
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: '', # Invalid: empty description
          amount: 0, # Invalid: zero amount
          transaction_type: 'income' # Valid transaction type
        }).permit!
      end

      it 'fails with validation errors' do
        result = described_class.call(transaction.id, invalid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('description no puede estar en blanco')
        expect(result.errors.full_messages).to include('amount debe ser diferente de 0')
      end
    end

    context 'with non-existent transaction' do
      let(:valid_params) do
        ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test transaction',
          amount: 100.50,
          transaction_type: 'income'
        }).permit!
      end

      it 'fails when transaction not found' do
        result = described_class.call(99999, valid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('Transaction not found')
      end
    end

    context 'with transaction belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_transaction) { create(:transaction, user: other_user) }
      let(:valid_params) do
        ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test transaction',
          amount: 100.50,
          transaction_type: 'income'
        }).permit!
      end

      it 'fails when trying to update another user\'s transaction' do
        result = described_class.call(other_transaction.id, valid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('Transaction not found')
      end
    end

    context 'with amount sign logic' do
      it 'handles positive amounts correctly' do
        income_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test income',
          amount: 100.50,
          transaction_type: 'income'
        }).permit!

        result = described_class.call(transaction.id, income_params)

        expect(result).to be_success
        expect(transaction.reload.amount).to eq(100.50)
      end

      it 'handles negative amounts correctly' do
        expense_params = ActionController::Parameters.new({
          bank_account_id: bank_account.id,
          date: Date.current,
          description: 'Test expense',
          amount: -100.50,
          transaction_type: 'variable_expense'
        }).permit!

        result = described_class.call(transaction.id, expense_params)

        expect(result).to be_success
        expect(transaction.reload.amount).to eq(-100.50)
      end
    end
  end
end
