# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transactions::Updater do
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
      it 'fails when amount is zero' do
        invalid_params = ActionController::Parameters.new({
          amount: 0
        }).permit!

        result = described_class.call(transaction.id, invalid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('amount debe ser diferente de 0')
      end

      it 'fails with empty description' do
        invalid_params = ActionController::Parameters.new({
          description: ''
        }).permit!

        result = described_class.call(transaction.id, invalid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('description no puede estar en blanco')
      end

      it 'fails when amount is not a valid number' do
        invalid_params = ActionController::Parameters.new({
          amount: 'invalid'
        }).permit!

        result = described_class.call(transaction.id, invalid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('amount debe ser diferente de 0')
      end

      it 'fails when date is invalid' do
        invalid_params = ActionController::Parameters.new({
          date: 'invalid-date'
        }).permit!

        result = described_class.call(transaction.id, invalid_params)

        expect(result).to be_failure
        expect(result.errors.full_messages).to include('date no puede estar en blanco')
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
        expect(result.errors.full_messages).to include(I18n.t('transactions.errors.not_found'))
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
        expect(result.errors.full_messages).to include(I18n.t('transactions.errors.not_found'))
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

    context 'with transfer transactions' do
      let(:source_account) { create(:bank_account, user: user) }
      let(:destination_account) { create(:bank_account, user: user) }
      let(:new_category) { create(:category, user: user, name: 'Updated Category') }

      let!(:transfer_out) do
        t = Transaction.new(
          user: user,
          bank_account: source_account,
          date: Date.today,
          description: 'Test Transfer',
          amount: -100,
          transaction_type: :transfer_out,
          source: :manual
        )
        t.save(validate: false)
        t
      end

      let!(:transfer_in) do
        t = Transaction.new(
          user: user,
          bank_account: destination_account,
          date: Date.today,
          description: 'Test Transfer',
          amount: 100,
          transaction_type: :transfer_in,
          source: :manual
        )
        t.save(validate: false)
        t
      end

      before do
        # Link the transfers together
        transfer_out.update_column(:linked_transfer_id, transfer_in.id)
        transfer_in.update_column(:linked_transfer_id, transfer_out.id)
        transfer_out.reload
        transfer_in.reload
      end

      it 'preserves transaction_type when updating a transfer' do
        update_params = ActionController::Parameters.new({
          transaction_type: 'income', # Try to change type
          description: 'Updated description',
          category_id: new_category.id
        }).permit!

        result = described_class.call(transfer_out.id, update_params)

        expect(result).to be_success
        expect(transfer_out.reload.transaction_type).to eq('transfer_out') # Should remain transfer_out
        expect(transfer_out.description).to eq('Updated description') # Other fields updated
      end

      it 'preserves bank_account_id when updating a transfer' do
        update_params = ActionController::Parameters.new({
          bank_account_id: destination_account.id, # Try to change account
          description: 'Updated description',
          category_id: new_category.id
        }).permit!

        result = described_class.call(transfer_out.id, update_params)

        expect(result).to be_success
        expect(transfer_out.reload.bank_account_id).to eq(source_account.id) # Should remain original account
        expect(transfer_out.description).to eq('Updated description') # Other fields updated
      end

      it 'syncs category to linked transfer when updating' do
        update_params = ActionController::Parameters.new({
          description: 'Updated description',
          category_id: new_category.id
        }).permit!

        result = described_class.call(transfer_out.id, update_params)

        expect(result).to be_success
        expect(transfer_out.reload.category_id).to eq(new_category.id)
        expect(transfer_in.reload.category_id).to eq(new_category.id) # Synced to linked transfer
      end

      it 'filters out transfer_account_id parameter' do
        update_params = ActionController::Parameters.new({
          transfer_account_id: destination_account.id, # Should be ignored
          description: 'Updated description',
          category_id: new_category.id
        }).permit!

        result = described_class.call(transfer_out.id, update_params)

        expect(result).to be_success
        expect(transfer_out.reload.description).to eq('Updated description')
      end
    end
  end
end
