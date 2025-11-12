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

  describe 'payment_mode validations' do
    let(:debt) { build(:debt, user: user) }

    it 'allows nil payment_mode' do
      debt.payment_mode = nil
      expect(debt).to be_valid
    end

    it 'allows fixed payment_mode' do
      debt.payment_mode = 'fixed'
      expect(debt).to be_valid
    end

    it 'allows calculated payment_mode' do
      debt.payment_mode = 'calculated'
      debt.target_payoff_date = 1.year.from_now
      expect(debt).to be_valid
    end

    it 'requires target_payoff_date when payment_mode is calculated' do
      debt.payment_mode = 'calculated'
      debt.target_payoff_date = nil
      expect(debt).not_to be_valid
      expect(debt.errors[:target_payoff_date]).to be_present
    end

    it 'does not require target_payoff_date when payment_mode is fixed' do
      debt.payment_mode = 'fixed'
      debt.target_payoff_date = nil
      expect(debt).to be_valid
    end
  end

  describe '#calculated_monthly_payment' do
    context 'with fixed payment mode' do
      let(:debt) { create(:debt, :with_fixed_payment, user: user, target_payment_amount: 500.0) }

      it 'returns the target_payment_amount' do
        expect(debt.calculated_monthly_payment).to eq(500.0)
      end
    end

    context 'with calculated payment mode' do
      let(:debt) do
        create(:debt, :with_calculated_payment, user: user,
               current_balance: 10000.0,
               interest_rate: 18.0,
               target_payoff_date: 2.years.from_now)
      end

      it 'calculates the required monthly payment with interest' do
        payment = debt.calculated_monthly_payment
        expect(payment).to be > 0
        expect(payment).to be_a(Numeric)
      end

      it 'returns 0 when target_payoff_date is blank' do
        debt.target_payoff_date = nil
        expect(debt.calculated_monthly_payment).to eq(0)
      end

      it 'returns 0 when current_balance is 0' do
        debt.current_balance = 0
        expect(debt.calculated_monthly_payment).to eq(0)
      end

      it 'calculates higher payments for shorter timeframes' do
        short_term_debt = create(:debt, :with_calculated_payment, user: user,
                                current_balance: 10000.0,
                                interest_rate: 18.0,
                                target_payoff_date: 1.year.from_now)
        long_term_debt = create(:debt, :with_calculated_payment, user: user,
                               current_balance: 10000.0,
                               interest_rate: 18.0,
                               target_payoff_date: 3.years.from_now)

        expect(short_term_debt.calculated_monthly_payment).to be > long_term_debt.calculated_monthly_payment
      end
    end

    context 'without payment mode' do
      let(:debt) { create(:debt, user: user, payment_mode: nil) }

      it 'returns 0' do
        expect(debt.calculated_monthly_payment).to eq(0)
      end
    end
  end

  describe '#suggested_payoff_date' do
    context 'with fixed payment mode' do
      let(:debt) do
        create(:debt, :with_fixed_payment, user: user,
               current_balance: 10000.0,
               interest_rate: 18.0,
               target_payment_amount: 500.0,
               payment_frequency: 'monthly')
      end

      it 'calculates a suggested payoff date' do
        date = debt.suggested_payoff_date
        expect(date).to be_a(Date)
        expect(date).to be > Date.current
      end

      it 'returns nil when target_payment_amount is blank' do
        debt.target_payment_amount = nil
        expect(debt.suggested_payoff_date).to be_nil
      end

      it 'returns nil when current_balance is 0' do
        debt.current_balance = 0
        expect(debt.suggested_payoff_date).to be_nil
      end

      it 'returns nil when payment does not cover interest' do
        debt.interest_rate = 50.0
        debt.target_payment_amount = 10.0
        expect(debt.suggested_payoff_date).to be_nil
      end

      it 'calculates earlier dates for higher payment amounts' do
        high_payment_debt = create(:debt, :with_fixed_payment, user: user,
                                   current_balance: 10000.0,
                                   interest_rate: 18.0,
                                   target_payment_amount: 1000.0)
        low_payment_debt = create(:debt, :with_fixed_payment, user: user,
                                  current_balance: 10000.0,
                                  interest_rate: 18.0,
                                  target_payment_amount: 300.0)

        expect(high_payment_debt.suggested_payoff_date).to be < low_payment_debt.suggested_payoff_date
      end
    end

    context 'with calculated payment mode' do
      let(:debt) { create(:debt, :with_calculated_payment, user: user) }

      it 'returns nil' do
        expect(debt.suggested_payoff_date).to be_nil
      end
    end

    context 'without payment mode' do
      let(:debt) { create(:debt, user: user, payment_mode: nil) }

      it 'returns nil' do
        expect(debt.suggested_payoff_date).to be_nil
      end
    end
  end

  describe 'payment frequency calculations' do
    let(:debt) do
      create(:debt, :with_calculated_payment, user: user,
             current_balance: 10000.0,
             interest_rate: 18.0,
             target_payoff_date: 1.year.from_now)
    end

    it 'calculates different payments for different frequencies' do
      weekly_payment = debt.tap { |d| d.payment_frequency = 'weekly' }.calculated_monthly_payment
      monthly_payment = debt.tap { |d| d.payment_frequency = 'monthly' }.calculated_monthly_payment

      expect(weekly_payment).to be > 0
      expect(monthly_payment).to be > 0
      expect(weekly_payment).to be < monthly_payment
    end
  end

  describe 'interest rate edge cases' do
    context 'with 0% interest rate' do
      let(:debt) do
        create(:debt, :with_calculated_payment, user: user,
               current_balance: 12000.0,
               interest_rate: 0.0,
               payment_frequency: 'monthly',
               target_payoff_date: 1.year.from_now)
      end

      it 'calculates payment as simple division' do
        # 12000 / 12 months = 1000
        expect(debt.calculated_monthly_payment).to eq(1000.0)
      end
    end

    context 'with no interest rate (nil)' do
      let(:debt) do
        create(:debt, :with_calculated_payment, user: user,
               current_balance: 12000.0,
               interest_rate: nil,
               payment_frequency: 'monthly',
               target_payoff_date: 1.year.from_now)
      end

      it 'treats nil as 0% interest' do
        # 12000 / 12 months = 1000
        expect(debt.calculated_monthly_payment).to eq(1000.0)
      end
    end
  end
end
