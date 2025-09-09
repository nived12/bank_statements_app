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
end
