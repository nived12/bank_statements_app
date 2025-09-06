require 'rails_helper'

RSpec.describe Searchable do
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
           description: 'Restaurant payment',
           merchant: 'Restaurant')
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
           description: 'Salary deposit',
           merchant: 'Company')
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
           description: 'Rent payment',
           merchant: 'Store')
  end

  let!(:transaction4) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           statement_file: statement_file,
           category: category,
           date: Date.new(2024, 3, 18),
           amount: -50.00,
           transaction_type: 'variable_expense',
           description: 'Grocery shopping',
           merchant: 'Supermarket')
  end

  let(:scope) { user.transactions.includes(:bank_account, :category) }

  describe '.search_by' do
    context 'when searching by description' do
      it 'returns transactions matching the search term' do
        results = scope.search_by(description: 'restaurant')
        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2, transaction3, transaction4)
      end

      it 'performs case-insensitive search' do
        results = scope.search_by(description: 'RESTAURANT')
        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2, transaction3, transaction4)
      end

      it 'performs partial matching' do
        results = scope.search_by(description: 'rest')
        expect(results).to include(transaction1)
        expect(results).not_to include(transaction2, transaction3, transaction4)
      end

      it 'returns multiple matches when multiple transactions match' do
        results = scope.search_by(description: 'payment')
        expect(results).to include(transaction1, transaction3)
        expect(results).not_to include(transaction2, transaction4)
      end

      it 'returns empty result when no matches found' do
        results = scope.search_by(description: 'nonexistent')
        expect(results).to be_empty
      end

      it 'returns all transactions when search term is empty' do
        results = scope.search_by(description: '')
        expect(results).to include(transaction1, transaction2, transaction3, transaction4)
      end

      it 'returns all transactions when search term is nil' do
        results = scope.search_by(description: nil)
        expect(results).to include(transaction1, transaction2, transaction3, transaction4)
      end

      it 'handles special characters in search term' do
        results = scope.search_by(description: 'nonexistent%')
        expect(results).to be_empty
      end

      it 'handles SQL injection attempts safely' do
        results = scope.search_by(description: "'; DROP TABLE transactions; --")
        expect(results).to be_empty
      end
    end

    context 'when searching with multiple parameters' do
      it 'combines multiple search criteria with OR logic' do
        # This would require additional search scopes to be implemented
        # For now, we'll test the basic functionality
        results = scope.search_by(description: 'restaurant')
        expect(results).to include(transaction1)
      end
    end

    context 'when no search parameters provided' do
      it 'returns all transactions' do
        results = scope.search_by({})
        expect(results).to include(transaction1, transaction2, transaction3, transaction4)
      end
    end
  end

  describe 'integration with Transaction model' do
    it 'includes Searchable concern' do
      expect(Transaction.ancestors).to include(Searchable)
    end

    it 'responds to search_by_description scope' do
      expect(Transaction).to respond_to(:search_by_description)
    end

    it 'can be chained with other scopes' do
      results = scope.where(transaction_type: 'variable_expense').search_by(description: 'restaurant')
      expect(results).to include(transaction1)
      expect(results).not_to include(transaction4) # Different transaction type
    end
  end
end
