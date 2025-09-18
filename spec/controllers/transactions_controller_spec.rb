# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionsController, type: :controller do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before do
    sign_in_user user
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Test transaction',
            amount: 100.50,
            transaction_type: 'income',
            category_id: category.id,
            merchant: 'Test Merchant',
            reference: 'REF123'
          }
        }
      end

      it 'creates a new transaction' do
        expect {
          post :create, params: valid_params
        }.to change(Transaction, :count).by(1)
      end

      it 'redirects to transactions index with success message' do
        post :create, params: valid_params
        expect(response).to redirect_to(transactions_path)
        expect(flash[:notice]).to eq('Transaction created successfully')
      end

      it 'creates transaction with correct attributes' do
        post :create, params: valid_params

        transaction = Transaction.last
        expect(transaction.user).to eq(user)
        expect(transaction.bank_account).to eq(bank_account)
        expect(transaction.description).to eq('Test transaction')
        expect(transaction.amount).to eq(100.50)
        expect(transaction.transaction_type).to eq('income')
        expect(transaction.category).to eq(category)
        expect(transaction.merchant).to eq('Test Merchant')
        expect(transaction.reference).to eq('REF123')
        expect(transaction.statement_file).to be_nil
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          transaction: {
            description: 'Incomplete transaction'
          }
        }
      end

      it 'does not create a transaction' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Transaction, :count)
      end

      it 'redirects to transactions index with error message' do
        post :create, params: invalid_params
        expect(response).to redirect_to(transactions_path)
        expect(flash[:alert]).to include('Failed to create transaction')
      end
    end
  end

  describe 'PATCH #update' do
    let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: nil, merchant: nil, reference: nil) }

    context 'with valid parameters' do
      let(:valid_params) do
        {
          id: transaction.id,
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Updated transaction',
            amount: 200.75,
            transaction_type: 'income',
            category_id: category.id,
            merchant: 'Updated Merchant',
            reference: 'UPD123'
          }
        }
      end

      it 'updates the transaction successfully' do
        patch :update, params: valid_params

        expect(response).to redirect_to(transactions_path)
        expect(flash[:notice]).to eq('Transaction updated successfully')

        transaction.reload
        expect(transaction.description).to eq('Updated transaction')
        expect(transaction.amount).to eq(200.75)
        expect(transaction.merchant).to eq('Updated Merchant')
        expect(transaction.reference).to eq('UPD123')
      end

      it 'updates with minimal parameters' do
        minimal_params = {
          id: transaction.id,
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Minimal update',
            amount: 50.00,
            transaction_type: 'variable_expense'
          }
        }

        patch :update, params: minimal_params

        expect(response).to redirect_to(transactions_path)
        expect(flash[:notice]).to eq('Transaction updated successfully')

        transaction.reload
        expect(transaction.description).to eq('Minimal update')
        expect(transaction.category).to be_nil
        expect(transaction.merchant).to be_nil
        expect(transaction.reference).to be_nil
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          id: transaction.id,
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: '', # Invalid: empty description
            amount: 0, # Invalid: zero amount
            transaction_type: 'invalid_type' # Invalid: invalid transaction type
          }
        }
      end

      it 'fails to update the transaction' do
        expect {
          patch :update, params: invalid_params
        }.not_to change { transaction.reload.description }
      end

      it 'redirects to transactions index with error message' do
        patch :update, params: invalid_params
        expect(response).to redirect_to(transactions_path)
        expect(flash[:alert]).to include('Failed to update transaction')
      end
    end

    context 'with non-existent transaction' do
      let(:valid_params) do
        {
          id: 99999,
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Test transaction',
            amount: 100.50,
            transaction_type: 'income'
          }
        }
      end

      it 'redirects to transactions index with error message' do
        patch :update, params: valid_params
        expect(response).to redirect_to(transactions_path)
        expect(flash[:alert]).to include('Failed to update transaction')
      end
    end

    context 'with transaction belonging to different user' do
      let(:other_user) { create(:user) }
      let(:other_transaction) { create(:transaction, user: other_user) }
      let(:valid_params) do
        {
          id: other_transaction.id,
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current,
            description: 'Test transaction',
            amount: 100.50,
            transaction_type: 'income'
          }
        }
      end

      it 'redirects to transactions index with error message' do
        patch :update, params: valid_params
        expect(response).to redirect_to(transactions_path)
        expect(flash[:alert]).to include('Failed to update transaction')
      end
    end
  end
end
