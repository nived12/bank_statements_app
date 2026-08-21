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
      expect(saving.errors[:base]).to include(I18n.t('savings.errors.categories_required_for_auto_sync'))
    end

    it 'requires bank accounts when auto_sync is enabled' do
      saving.category_ids = [category1.id]
      saving.auto_sync_transactions = true
      saving.save
      expect(saving.errors[:base]).to include(I18n.t('savings.errors.bank_accounts_required_for_auto_sync'))
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

  describe 'target_date validations' do
    it 'does not require target_date when contribution_mode is nil' do
      saving = build(:saving, user: user, contribution_mode: nil, target_date: nil)
      expect(saving).to be_valid
    end

    it 'does not require target_date when contribution_mode is fixed' do
      saving = build(:saving, user: user, contribution_mode: 'fixed', target_date: nil)
      expect(saving).to be_valid
    end

    it 'requires target_date when contribution_mode is calculated' do
      saving = build(:saving, user: user, contribution_mode: 'calculated', target_date: nil)
      expect(saving).not_to be_valid
      expect(saving.errors[:target_date]).to be_present
    end

    it 'is valid when contribution_mode is calculated and target_date is present' do
      saving = build(:saving, user: user, contribution_mode: 'calculated', target_date: 1.year.from_now)
      expect(saving).to be_valid
    end
  end

  describe '#suggested_target_date' do
    let(:saving) do
      create(
        :saving,
        user: user,
        target_amount: 12000,
        opening_balance: 2000,
        contribution_mode: 'fixed',
        target_contribution_amount: 1000
      )
    end

    it 'calculates suggested date based on fixed contribution amount' do
      # Remaining: 12000 - 2000 = 10000
      # Months needed: 10000 / 1000 = 10 months
      expected_date = Date.current + 10.months
      expect(saving.suggested_target_date).to eq(expected_date)
    end

    it 'returns nil when contribution_mode is not fixed' do
      saving.update(contribution_mode: 'calculated')
      expect(saving.suggested_target_date).to be_nil
    end

    it 'returns nil when target_contribution_amount is blank' do
      saving.update(target_contribution_amount: nil)
      expect(saving.suggested_target_date).to be_nil
    end

    it 'returns nil when target_contribution_amount is zero' do
      saving.update(target_contribution_amount: 0)
      expect(saving.suggested_target_date).to be_nil
    end

    it 'returns current date when target is already reached' do
      saving.update(current_amount: 15000)
      expect(saving.suggested_target_date).to eq(Date.current)
    end
  end

  describe '#calculate_required_monthly_contribution' do
    let(:saving) do
      create(
        :saving,
        user: user,
        target_amount: 12000,
        opening_balance: 2000,
        contribution_mode: 'calculated',
        target_date: 10.months.from_now.to_date
      )
    end

    it 'calculates required monthly contribution based on target_date' do
      # Remaining: 12000 - 2000 = 10000
      # Months: 10
      # Required: 10000 / 10 = 1000
      expect(saving.calculated_monthly_contribution).to eq(1000.0)
    end

    it 'returns 0 when target_date is blank' do
      saving.update(target_date: nil)
      expect(saving.send(:calculate_required_monthly_contribution)).to eq(0)
    end

    it 'returns 0 when target is already reached' do
      saving.update(current_amount: 15000)
      expect(saving.send(:calculate_required_monthly_contribution)).to eq(0)
    end

    it 'returns remaining amount when target_date is in the past' do
      saving.update(target_date: 1.month.ago)
      expect(saving.send(:calculate_required_monthly_contribution)).to eq(10000)
    end
  end

  describe 'opening_balance anchor' do
    let(:bank_account) { create(:bank_account, user: user) }

    def linked_transaction(saving, date:, amount:)
      transaction = create(
        :transaction, user: user, bank_account: bank_account, category: category1,
        date: date, amount: amount
      )
      SavingTransaction.create!(saving: saving, transaction_id: transaction.id, amount_applied: amount, manual: true)
      transaction
    end

    context 'the reported bug: a typed baseline surviving a link' do
      let(:saving) do
        create(
          :saving, user: user, target_amount: 120_000, opening_balance: 50_000,
          opening_balance_date: Date.current
        )
      end

      it 'keeps the typed baseline instead of discarding it for the sum of links' do
        linked_transaction(saving, date: Date.current + 1.day, amount: 5_000)

        expect(saving.reload.current_amount).to eq(55_000)
      end
    end

    it 'does not count a transaction dated on or before opening_balance_date' do
      saving = create(:saving, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15))

      expect {
        linked_transaction(saving, date: Date.new(2026, 1, 15), amount: 500)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'counts a transaction dated after opening_balance_date' do
      saving = create(:saving, user: user, opening_balance: 1_000, opening_balance_date: Date.new(2026, 1, 15))
      linked_transaction(saving, date: Date.new(2026, 1, 16), amount: 500)

      expect(saving.reload.current_amount).to eq(1_500)
    end

    it 'rejects an opening_balance_date in the future' do
      saving = build(:saving, user: user, opening_balance_date: 1.day.from_now.to_date)

      expect(saving).not_to be_valid
      expect(saving.errors[:opening_balance_date]).to be_present
    end

    describe '#balance_as_of' do
      it 'returns opening_balance_date when nothing is linked after it' do
        saving = create(:saving, user: user, opening_balance_date: Date.new(2026, 1, 15))

        expect(saving.balance_as_of).to eq(Date.new(2026, 1, 15))
      end

      it 'follows the newest counted transaction' do
        saving = create(:saving, user: user, opening_balance: 0, opening_balance_date: Date.new(2026, 1, 15))
        linked_transaction(saving, date: Date.new(2026, 1, 20), amount: 100)

        expect(saving.balance_as_of).to eq(Date.new(2026, 1, 20))
      end
    end
  end
end
