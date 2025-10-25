require 'rails_helper'

RSpec.describe Saving, type: :model do
  let(:user) { create(:user) }
  let(:category1) { create(:category, user: user, name: 'Groceries') }
  let(:category2) { create(:category, user: user, name: 'Transport') }
  let(:bank_account1) { create(:bank_account, user: user) }
  let(:bank_account2) { create(:bank_account, user: user) }

  describe 'multiple categories and bank accounts' do
    let(:saving) { create(:saving, user: user) }

    it 'can have multiple categories' do
      saving.category_ids = [category1.id, category2.id]
      expect(saving.categories.count).to eq(2)
      expect(saving.categories).to include(category1, category2)
    end

    it 'can have multiple bank accounts' do
      saving.bank_account_ids = [bank_account1.id, bank_account2.id]
      expect(saving.bank_accounts.count).to eq(2)
      expect(saving.bank_accounts).to include(bank_account1, bank_account2)
    end

    it 'can update categories' do
      saving.category_ids = [category1.id]
      expect(saving.categories).to include(category1)

      saving.category_ids = [category2.id]
      expect(saving.categories).to include(category2)
      expect(saving.categories).not_to include(category1)
    end

    it 'can update bank accounts' do
      saving.bank_account_ids = [bank_account1.id]
      expect(saving.bank_accounts).to include(bank_account1)

      saving.bank_account_ids = [bank_account2.id]
      expect(saving.bank_accounts).to include(bank_account2)
      expect(saving.bank_accounts).not_to include(bank_account1)
    end
  end

  describe 'auto_sync validations on update' do
    let!(:saving) { create(:saving, user: user, auto_sync_transactions: false) }

    it 'requires categories when auto_sync is enabled' do
      saving.auto_sync_transactions = true
      saving.save
      expect(saving.errors[:base]).to include('At least one category is required when auto-sync is enabled')
    end

    it 'requires bank accounts when auto_sync is enabled' do
      saving.category_ids = [category1.id]
      saving.auto_sync_transactions = true
      saving.save
      expect(saving.errors[:base]).to include('At least one bank account is required when auto-sync is enabled')
    end

    it 'is valid when auto_sync is enabled with categories and bank accounts' do
      saving.category_ids = [category1.id]
      saving.bank_account_ids = [bank_account1.id]
      saving.auto_sync_transactions = true
      expect(saving.save).to be true
    end

    it 'does not require categories or bank accounts when auto_sync is disabled' do
      saving.auto_sync_transactions = false
      expect(saving.save).to be true
    end
  end

  describe 'scopes' do
    let!(:active_saving) { create(:saving, :active, user: user) }
    let!(:auto_sync_saving) { create(:saving, :with_auto_sync, user: user) }

    it 'filters active savings' do
      expect(Saving.active).to include(active_saving)
    end

    it 'filters savings with auto_sync' do
      expect(Saving.with_auto_sync).to include(auto_sync_saving)
      expect(Saving.with_auto_sync).not_to include(active_saving)
    end
  end
end
