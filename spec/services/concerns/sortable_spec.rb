require 'rails_helper'

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

  let(:scope) { user.transactions.includes(:bank_account, :category) }

  describe '.order_by' do
    context 'sorting by date' do
      it 'sorts by date descending' do
        result = scope.order_by(:date, :desc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end

      it 'sorts by date ascending' do
        result = scope.order_by(:date, :asc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction1)  # Oldest
        expect(transactions.last).to eq(transaction3)   # Most recent
      end

      it 'uses provided direction over default' do
        result = scope.order_by(:date, :asc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction1)  # Oldest (asc)
        expect(transactions.last).to eq(transaction3)   # Most recent (asc)
      end
    end

    context 'sorting by amount' do
      it 'sorts by amount descending' do
        result = scope.order_by(:amount, :desc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction2)  # Highest amount (2500.00)
        expect(transactions.last).to eq(transaction3)   # Lowest amount (-100.00)
      end

      it 'sorts by amount ascending' do
        result = scope.order_by(:amount, :asc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3)  # Lowest amount (-100.00)
        expect(transactions.last).to eq(transaction2)   # Highest amount (2500.00)
      end
    end

    context 'sorting by description' do
      it 'sorts by description ascending' do
        result = scope.order_by(:description, :asc)

        transactions = result.to_a
        expect(transactions.first.description).to eq('A Restaurant payment')
        expect(transactions.last.description).to eq('Z Salary deposit')
      end

      it 'sorts by description descending' do
        result = scope.order_by(:description, :desc)

        transactions = result.to_a
        expect(transactions.first.description).to eq('Z Salary deposit')
        expect(transactions.last.description).to eq('A Restaurant payment')
      end
    end

    context 'sorting by transaction_type' do
      it 'sorts by transaction_type ascending' do
        result = scope.order_by(:transaction_type, :asc)

        transactions = result.to_a
        expect(transactions.first.transaction_type).to eq('fixed_expense')
        expect(transactions.last.transaction_type).to eq('variable_expense')
      end

      it 'sorts by transaction_type descending' do
        result = scope.order_by(:transaction_type, :desc)

        transactions = result.to_a
        expect(transactions.first.transaction_type).to eq('variable_expense')
        expect(transactions.last.transaction_type).to eq('fixed_expense')
      end
    end

    context 'sorting by category' do
      it 'sorts by category name ascending' do
        result = scope.order_by(:category, :asc)

        transactions = result.to_a
        # All transactions have the same category, so order should be preserved
        expect(transactions.count).to eq(3)
        expect(transactions.first.category.name).to eq('Test Category')
      end

      it 'sorts by category name descending' do
        result = scope.order_by(:category, :desc)

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.category.name).to eq('Test Category')
      end
    end

    context 'sorting by merchant' do
      it 'sorts by merchant ascending' do
        result = scope.order_by(:merchant, :asc)

        transactions = result.to_a
        expect(transactions.first.merchant).to eq('A Company')
        expect(transactions.last.merchant).to eq('Z Restaurant')
      end

      it 'sorts by merchant descending' do
        result = scope.order_by(:merchant, :desc)

        transactions = result.to_a
        expect(transactions.first.merchant).to eq('Z Restaurant')
        expect(transactions.last.merchant).to eq('A Company')
      end
    end

    context 'sorting by bank_account' do
      it 'sorts by bank name ascending' do
        result = scope.order_by(:bank_account, :asc)

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.bank_account.bank.name).to eq(bank.name)
      end

      it 'sorts by bank name descending' do
        result = scope.order_by(:bank_account, :desc)

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        expect(transactions.first.bank_account.bank.name).to eq(bank.name)
      end
    end

    context 'with multiple sort parameters' do
      it 'applies single sort (multiple sorts not supported in new API)' do
        result = scope.order_by(:transaction_type, :asc)

        transactions = result.to_a
        expect(transactions.count).to eq(3)
        # Sorts by transaction_type only
        expect(transactions.first.transaction_type).to eq('fixed_expense')
      end
    end

    context 'with invalid sort fields' do
      it 'falls back to date when invalid field provided' do
        result = scope.order_by(:invalid_field, :desc)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent (date desc fallback)
        expect(transactions.last).to eq(transaction1)  # Oldest (date desc fallback)
      end
    end

    context 'with default direction' do
      it 'uses desc as default direction' do
        result = scope.order_by(:date)

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent (date desc)
        expect(transactions.last).to eq(transaction1)  # Oldest (date desc)
      end
    end

    context 'with blank field' do
      it 'returns all records when field is blank' do
        result = scope.order_by(nil)

        transactions = result.to_a
        expect(transactions.count).to eq(3)
      end
    end

    context 'direction case handling' do
      it 'handles uppercase direction' do
        result = scope.order_by(:date, 'DESC')

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end

      it 'handles mixed case direction' do
        result = scope.order_by(:date, 'Desc')

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end

      it 'defaults to desc for invalid direction values' do
        result = scope.order_by(:date, 'invalid')

        transactions = result.to_a
        expect(transactions.first).to eq(transaction3)  # Most recent (desc default)
        expect(transactions.last).to eq(transaction1)   # Oldest (desc default)
      end
    end
  end
end
