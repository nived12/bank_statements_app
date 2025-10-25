require 'rails_helper'

RSpec.describe Debt, type: :model do
  let(:user) { create(:user) }
  let(:category1) { create(:category, user: user, name: 'Credit Card') }
  let(:category2) { create(:category, user: user, name: 'Loan Payment') }
  let(:bank_account1) { create(:bank_account, user: user) }
  let(:bank_account2) { create(:bank_account, user: user) }

  describe 'multiple categories and bank accounts' do
    let(:debt) { create(:debt, user: user) }

    it 'can have multiple categories' do
      debt.category_ids = [category1.id, category2.id]

      expect(debt.categories.count).to eq(2)
      expect(debt.categories).to include(category1, category2)
    end

    it 'can have multiple bank accounts' do
      debt.bank_account_ids = [bank_account1.id, bank_account2.id]

      expect(debt.bank_accounts.count).to eq(2)
      expect(debt.bank_accounts).to include(bank_account1, bank_account2)
    end

    it 'can update categories' do
      debt.category_ids = [category1.id]
      expect(debt.categories).to include(category1)

      debt.category_ids = [category2.id]
      expect(debt.categories).to include(category2)
      expect(debt.categories).not_to include(category1)
    end

    it 'can update bank accounts' do
      debt.bank_account_ids = [bank_account1.id]
      expect(debt.bank_accounts).to include(bank_account1)

      debt.bank_account_ids = [bank_account2.id]
      expect(debt.bank_accounts).to include(bank_account2)
      expect(debt.bank_accounts).not_to include(bank_account1)
    end
  end

  describe 'auto_sync validations on update' do
    let!(:debt) { create(:debt, user: user, auto_sync_transactions: false) }

    it 'requires categories when auto_sync is enabled' do
      debt.auto_sync_transactions = true
      debt.save

      expect(debt.errors[:base]).to include('At least one category is required when auto-sync is enabled')
    end

    it 'requires bank accounts when auto_sync is enabled' do
      debt.category_ids = [category1.id]
      debt.auto_sync_transactions = true
      debt.save

      expect(debt.errors[:base]).to include('At least one bank account is required when auto-sync is enabled')
    end

    it 'is valid when auto_sync is enabled with categories and bank accounts' do
      debt.category_ids = [category1.id]
      debt.bank_account_ids = [bank_account1.id]
      debt.auto_sync_transactions = true

      expect(debt.save).to be true
    end

    it 'does not require categories or bank accounts when auto_sync is disabled' do
      debt.auto_sync_transactions = false

      expect(debt.save).to be true
    end
  end

  describe 'scopes' do
    let!(:active_debt) { create(:debt, :active, user: user) }
    let!(:auto_sync_debt) { create(:debt, :with_auto_sync, user: user) }

    describe '.active' do
      it 'returns only active debts' do
        expect(Debt.active).to include(active_debt)
      end
    end

    describe '.with_auto_sync' do
      it 'returns debts with auto_sync enabled' do
        expect(Debt.with_auto_sync).to include(auto_sync_debt)
        expect(Debt.with_auto_sync).not_to include(active_debt)
      end
    end
  end
end
