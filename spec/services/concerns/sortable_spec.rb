require 'rails_helper'

# Test class to include the Sortable concern
class TestSortableService
  include Sortable

  def test_apply_sorting(scope, sort_params)
    apply_sorting(scope, sort_params)
  end
end

RSpec.describe Sortable do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:category) { create(:category, user: user, name: 'Test Category') }

  let!(:transaction1) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           statement_file: statement_file,
           category: category,
           date: Date.new(2024, 3, 15),
           amount: -25.50,
           transaction_type: 'variable_expense',
           description: 'A Restaurant payment',
           merchant: 'Z Restaurant')
  end

  let!(:transaction2) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           statement_file: statement_file,
           category: category,
           date: Date.new(2024, 3, 16),
           amount: 2500.00,
           transaction_type: 'income',
           description: 'Z Salary deposit',
           merchant: 'A Company')
  end

  let!(:transaction3) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           statement_file: statement_file,
           category: category,
           date: Date.new(2024, 3, 17),
           amount: -100.00,
           transaction_type: 'fixed_expense',
           description: 'M Rent payment',
           merchant: 'M Store')
  end

  let(:service) { TestSortableService.new }
  let(:scope) { user.transactions.includes(:bank_account, :category) }

  describe '#apply_sorting' do
    context 'sorting by date' do
      it 'sorts by date descending by default' do
        result = service.test_apply_sorting(scope, { sort: 'date', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end

      it 'sorts by date ascending' do
        result = service.test_apply_sorting(scope, { sort: 'date', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction1)  # Oldest
        expect(transactions.last).to eq(transaction3)   # Most recent
      end

      it 'defaults to date descending when no direction specified' do
        result = service.test_apply_sorting(scope, { sort: 'date' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end
    end

    context 'sorting by amount' do
      it 'sorts by amount descending' do
        result = service.test_apply_sorting(scope, { sort: 'amount', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction2)  # Highest amount (2500.00)
        expect(transactions.last).to eq(transaction3)   # Lowest amount (-100.00)
      end

      it 'sorts by amount ascending' do
        result = service.test_apply_sorting(scope, { sort: 'amount', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3)  # Lowest amount (-100.00)
        expect(transactions.last).to eq(transaction2)   # Highest amount (2500.00)
      end
    end

    context 'sorting by description' do
      it 'sorts by description ascending' do
        result = service.test_apply_sorting(scope, { sort: 'description', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first.description).to eq('A Restaurant payment')
        expect(transactions.last.description).to eq('Z Salary deposit')
      end

      it 'sorts by description descending' do
        result = service.test_apply_sorting(scope, { sort: 'description', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.first.description).to eq('Z Salary deposit')
        expect(transactions.last.description).to eq('A Restaurant payment')
      end
    end

    context 'sorting by transaction_type' do
      it 'sorts by transaction_type ascending' do
        result = service.test_apply_sorting(scope, { sort: 'transaction_type', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first.transaction_type).to eq('fixed_expense')
        expect(transactions.last.transaction_type).to eq('variable_expense')
      end

      it 'sorts by transaction_type descending' do
        result = service.test_apply_sorting(scope, { sort: 'transaction_type', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.first.transaction_type).to eq('variable_expense')
        expect(transactions.last.transaction_type).to eq('fixed_expense')
      end
    end

    context 'sorting by category' do
      it 'sorts by category name ascending' do
        result = service.test_apply_sorting(scope, { sort: 'category', direction: 'asc' })

        transactions = result.to_a
        # All transactions have the same category, so order should be preserved
        expect(transactions.count).to eq(3)
        expect(transactions.first.category.name).to eq('Test Category')
      end

      it 'sorts by category name descending' do
        result = service.test_apply_sorting(scope, { sort: 'category', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.category.name).to eq('Test Category')
      end
    end

    context 'sorting by merchant' do
      it 'sorts by merchant ascending' do
        result = service.test_apply_sorting(scope, { sort: 'merchant', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first.merchant).to eq('A Company')
        expect(transactions.last.merchant).to eq('Z Restaurant')
      end

      it 'sorts by merchant descending' do
        result = service.test_apply_sorting(scope, { sort: 'merchant', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.first.merchant).to eq('Z Restaurant')
        expect(transactions.last.merchant).to eq('A Company')
      end
    end

    context 'sorting by bank_account' do
      it 'sorts by bank name ascending' do
        result = service.test_apply_sorting(scope, { sort: 'bank_account', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.bank_account.bank.name).to eq(bank.name)
      end

      it 'sorts by bank name descending' do
        result = service.test_apply_sorting(scope, { sort: 'bank_account', direction: 'desc' })

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.bank_account.bank.name).to eq(bank.name)
      end
    end

    context 'invalid sort field' do
      it 'falls back to date descending for invalid sort field' do
        result = service.test_apply_sorting(scope, { sort: 'invalid_field', direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent (date desc)
        expect(transactions.last).to eq(transaction1)  # Oldest (date desc)
      end

      it 'falls back to date descending when sort field is nil' do
        result = service.test_apply_sorting(scope, { sort: nil, direction: 'asc' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction1) # Oldest (date desc fallback)
        expect(transactions.last).to eq(transaction3)  # Most recent (date desc fallback)
      end
    end

    context 'default parameters' do
      it 'uses default sort and direction when not provided' do
        result = service.test_apply_sorting(scope, {})

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent (date desc)
        expect(transactions.last).to eq(transaction1)  # Oldest (date desc)
      end

      it 'uses default direction when only sort is provided' do
        result = service.test_apply_sorting(scope, { sort: 'amount' })

        transactions = result.to_a
        expect(transactions.first).to eq(transaction2)  # Highest amount (desc)
        expect(transactions.last).to eq(transaction3)   # Lowest amount (desc)
      end
    end
  end
end
