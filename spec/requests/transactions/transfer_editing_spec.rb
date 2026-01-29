# spec/requests/transactions/transfer_editing_spec.rb
require 'rails_helper'

RSpec.describe 'Transfer Transaction Editing', type: :request do
  let(:user) { create(:user) }
  let(:checking_account) { create(:bank_account, user: user, custom_name: 'Checking') }
  let(:savings_account) { create(:bank_account, user: user, custom_name: 'Savings') }
  let(:category) { create(:category, user: user, name: 'Transfer Category') }
  let(:new_category) { create(:category, user: user, name: 'Updated Category') }

  before do
    sign_in_user(user)
  end

  describe 'POST /transactions - creating transfers with category' do
    it 'sets category on both transfer_out and transfer_in transactions' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          transfer_account_id: savings_account.id,
          date: Date.today.to_s,
          amount: 100.00,
          description: 'Transfer with category',
          category_id: category.id
        }
      }

      expect(response).to have_http_status(:found) # Redirect after create

      # Verify both transactions have the category
      transfer_out = user.transactions.find_by(
        transaction_type: :transfer_out,
        bank_account_id: checking_account.id
      )
      transfer_in = user.transactions.find_by(
        transaction_type: :transfer_in,
        bank_account_id: savings_account.id
      )

      expect(transfer_out).to be_present
      expect(transfer_in).to be_present
      expect(transfer_out.category_id).to eq(category.id)
      expect(transfer_in.category_id).to eq(category.id)
      expect(transfer_out.linked_transfer_id).to eq(transfer_in.id)
      expect(transfer_in.linked_transfer_id).to eq(transfer_out.id)
    end

    it 'creates transfer with merchant and reference fields' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          transfer_account_id: savings_account.id,
          date: Date.today.to_s,
          amount: 200.00,
          description: 'Transfer with metadata',
          category_id: category.id,
          merchant: 'Bank Transfer',
          reference: 'REF-12345'
        }
      }

      expect(response).to have_http_status(:found)

      transfer_out = user.transactions.find_by(transaction_type: :transfer_out)
      transfer_in = user.transactions.find_by(transaction_type: :transfer_in)

      expect(transfer_out.merchant).to eq('Bank Transfer')
      expect(transfer_out.reference).to eq('REF-12345')
      expect(transfer_in.merchant).to eq('Bank Transfer')
      expect(transfer_in.reference).to eq('REF-12345')
    end

    it 'creates transfer with correct amounts (negative source, positive destination)' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          transfer_account_id: savings_account.id,
          date: Date.today.to_s,
          amount: 150.00,
          description: 'Amount test'
        }
      }

      transfer_out = user.transactions.find_by(transaction_type: :transfer_out)
      transfer_in = user.transactions.find_by(transaction_type: :transfer_in)

      expect(transfer_out.amount).to eq(-150.00)
      expect(transfer_in.amount).to eq(150.00)
    end
  end

  describe 'PATCH /transactions/:id - editing transfer transactions' do
    let!(:transfer_pair) do
      # Use the service to create a proper transfer pair
      Current.user = user
      result = Transactions::Creator.call(
        ActionController::Parameters.new(
          {
                    transaction_type: 'transfer_out',
                    bank_account_id: checking_account.id,
                    transfer_account_id: savings_account.id,
                    date: Date.today.to_s,
                    amount: 150.00,
                    description: 'Original transfer',
                    category_id: category.id
                  }
        ).permit!
      )
      Current.user = nil
      result
    end

    let(:transfer_out) { transfer_pair.payload }
    let(:transfer_in) { transfer_pair.payload.linked_transfer }

    it 'preserves transaction_type when attempting to change it' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          transaction_type: 'income', # Try to change type
          description: 'Updated transfer',
          amount: 175.00
        }
      }

      expect(response).to have_http_status(:found)

      transfer_out.reload
      transfer_in.reload

      # Type should be preserved
      expect(transfer_out.transaction_type).to eq('transfer_out')
      expect(transfer_in.transaction_type).to eq('transfer_in')

      # But description and amount should be updated
      expect(transfer_out.description).to eq('Updated transfer')
      expect(transfer_out.amount.to_f).to eq(-175.00)
      expect(transfer_in.amount.to_f).to eq(175.00)
    end

    it 'preserves bank_account_id when attempting to change it' do
      other_account = create(:bank_account, user: user, custom_name: 'Other Account')

      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          bank_account_id: other_account.id, # Try to change account
          description: 'Account change attempt'
        }
      }

      transfer_out.reload
      transfer_in.reload

      # Accounts should be preserved
      expect(transfer_out.bank_account_id).to eq(checking_account.id)
      expect(transfer_in.bank_account_id).to eq(savings_account.id)
    end

    it 'syncs category to linked transfer when updating' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          category_id: new_category.id,
          description: 'Category update'
        }
      }

      transfer_out.reload
      transfer_in.reload

      # Both should have new category
      expect(transfer_out.category_id).to eq(new_category.id)
      expect(transfer_in.category_id).to eq(new_category.id)
    end

    it 'syncs description to linked transfer' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          description: 'New description'
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_out.description).to eq('New description')
      expect(transfer_in.description).to eq('New description')
    end

    it 'syncs amount to linked transfer (with opposite sign)' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          amount: 250.00
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_out.amount).to eq(-250.00)
      expect(transfer_in.amount).to eq(250.00)
    end

    it 'syncs date to linked transfer' do
      new_date = Date.today - 5.days

      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          date: new_date.to_s
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_out.date).to eq(new_date)
      expect(transfer_in.date).to eq(new_date)
    end

    it 'syncs merchant to linked transfer' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          merchant: 'Updated Merchant'
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_out.merchant).to eq('Updated Merchant')
      expect(transfer_in.merchant).to eq('Updated Merchant')
    end

    it 'syncs reference to linked transfer' do
      patch "/transactions/#{transfer_out.id}", params: {
        transaction: {
          reference: 'REF-UPDATED'
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_out.reference).to eq('REF-UPDATED')
      expect(transfer_in.reference).to eq('REF-UPDATED')
    end

    it 'can edit a transfer_in transaction (edits as if it were transfer_out)' do
      # The UI converts transfer_in to transfer_out for editing
      # The update service should handle this correctly
      patch "/transactions/#{transfer_in.id}", params: {
        transaction: {
          description: 'Edited via transfer_in',
          amount: 300.00
        }
      }

      transfer_out.reload
      transfer_in.reload

      expect(transfer_in.description).to eq('Edited via transfer_in')
      expect(transfer_in.amount).to eq(300.00)
      expect(transfer_out.amount).to eq(-300.00)
    end
  end

  describe 'GET /transactions - displaying transfers' do
    let!(:transfer_pair) do
      Current.user = user
      result = Transactions::Creator.call(
        ActionController::Parameters.new(
          {
                    transaction_type: 'transfer_out',
                    bank_account_id: checking_account.id,
                    transfer_account_id: savings_account.id,
                    date: Date.today.to_s,
                    amount: 100.00,
                    description: 'Display test transfer',
                    category_id: category.id
                  }
        ).permit!
      )
      Current.user = nil
      result
    end

    let(:transfer_out) { transfer_pair.payload }
    let(:transfer_in) { transfer_pair.payload.linked_transfer }

    it 'displays transfer transactions with correct data attributes' do
      get "/transactions"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Display test transfer')
      expect(response.body).to include("data-transaction-id=\"#{transfer_out.id}\"")
      expect(response.body).to include("data-transaction-id=\"#{transfer_in.id}\"")
    end

    it 'includes category information in data attributes' do
      get "/transactions"

      expect(response.body).to include("data-category-id=\"#{category.id}\"")
    end

    it 'includes transfer account information for transfer_out in JSON' do
      get "/transactions.json"

      json = JSON.parse(response.body)
      transfer_out_json = json["transactions"].find { |t| t["id"] == transfer_out.id }

      expect(transfer_out_json).to be_present
      expect(transfer_out_json["transfer_account_id"]).to eq(savings_account.id)
      expect(transfer_out_json["transfer_account"]["id"]).to eq(savings_account.id)
    end

    it 'displays both transfer_out and transfer_in transactions' do
      get "/transactions"

      expect(response.body).to include('data-transaction-type="transfer_out"')
      expect(response.body).to include('data-transaction-type="transfer_in"')
    end
  end

  describe 'DELETE /transactions/:id - deleting transfers' do
    let!(:transfer_pair) do
      Current.user = user
      result = Transactions::Creator.call(
        ActionController::Parameters.new(
          {
                    transaction_type: 'transfer_out',
                    bank_account_id: checking_account.id,
                    transfer_account_id: savings_account.id,
                    date: Date.today.to_s,
                    amount: 100.00,
                    description: 'Delete test transfer'
                  }
        ).permit!
      )
      Current.user = nil
      result
    end

    let(:transfer_out) { transfer_pair.payload }
    let(:transfer_in) { transfer_pair.payload.linked_transfer }

    it 'deletes both transfer_out and linked transfer_in (cascade delete)' do
      transfer_out_id = transfer_out.id
      transfer_in_id = transfer_in.id

      expect {
        delete "/transactions/#{transfer_out.id}"
      }.to change(Transaction, :count).by(-2)

      expect(Transaction.find_by(id: transfer_out_id)).to be_nil
      expect(Transaction.find_by(id: transfer_in_id)).to be_nil
    end

    it 'deletes both transfer_in and linked transfer_out (cascade delete)' do
      expect {
        delete "/transactions/#{transfer_in.id}"
      }.to change(Transaction, :count).by(-2)

      expect(Transaction.find_by(id: transfer_out.id)).to be_nil
      expect(Transaction.find_by(id: transfer_in.id)).to be_nil
    end
  end

  describe 'Date handling in transfers' do
    it 'uses local timezone not UTC when creating transfer' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          transfer_account_id: savings_account.id,
          date: '2025-03-15',
          amount: 100.00,
          description: 'Date test'
        }
      }

      transfer_out = user.transactions.find_by(description: 'Date test', transaction_type: :transfer_out)

      expect(transfer_out.date).to eq(Date.new(2025, 3, 15))
      expect(transfer_out.date.to_s).to eq('2025-03-15')
    end
  end

  describe 'Error handling in transfers' do
    it 'returns error when trying to create transfer without destination account' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          # Missing transfer_account_id
          date: Date.today.to_s,
          amount: 100.00,
          description: 'Invalid transfer'
        }
      }

      # Should render form with errors
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash.now[:alert]).to be_present
    end

    it 'returns error when trying to create transfer to same account' do
      post "/transactions", params: {
        transaction: {
          transaction_type: 'transfer_out',
          bank_account_id: checking_account.id,
          transfer_account_id: checking_account.id, # Same as source
          date: Date.today.to_s,
          amount: 100.00,
          description: 'Self transfer'
        }
      }

      # Should render form with errors
      expect(response).to have_http_status(:unprocessable_content)

      # Should not create any transactions
      expect(user.transactions.where(description: 'Self transfer')).to be_empty
    end
  end
end
