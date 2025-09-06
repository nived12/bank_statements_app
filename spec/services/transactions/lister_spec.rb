require 'rails_helper'

RSpec.describe Transactions::Lister do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:category) { create(:category, user: user) }

  let!(:transaction1) do
    create(:transaction,
           user: user,
           bank_account: bank_account,
           statement_file: statement_file,
           category: category,
           date: Date.new(2024, 3, 15),
           amount: -25.50,
           transaction_type: 'variable_expense',
           description: 'Restaurant payment')
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
           description: 'Salary deposit')
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
           description: 'Rent payment')
  end

  describe '.call' do
    context 'with no params' do
      it 'returns all user transactions' do
        result = described_class.call(user, {})

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1, transaction2, transaction3)
        expect(result.payload[:current_sort]).to eq('date')
        expect(result.payload[:current_direction]).to eq('desc')
      end
    end

    context 'with bank account filter' do
      let(:other_bank_account) { create(:bank_account, user: user, bank: bank) }
      let!(:other_transaction) do
        create(:transaction,
               user: user,
               bank_account: other_bank_account,
               statement_file: statement_file,
               category: category)
      end

      it 'filters by bank account' do
        result = described_class.call(user, { bank_account_id: bank_account.id })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1, transaction2, transaction3)
        expect(result.payload[:transactions]).not_to include(other_transaction)
      end
    end

    context 'with statement file filter' do
      let(:other_statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
      let!(:other_transaction) do
        create(:transaction,
               user: user,
               bank_account: bank_account,
               statement_file: other_statement_file,
               category: category)
      end

      it 'filters by statement file' do
        result = described_class.call(user, { statement_file_id: statement_file.id })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1, transaction2, transaction3)
        expect(result.payload[:transactions]).not_to include(other_transaction)
        expect(result.payload[:statement_file]).to eq(statement_file)
      end

      it 'automatically includes bank account filter when statement file is selected' do
        result = described_class.call(user, { statement_file_id: statement_file.id })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1, transaction2, transaction3)
      end

      it 'returns error when statement file not found' do
        result = described_class.call(user, { statement_file_id: 99999 })

        expect(result.success?).to be false
        expect(result.errors.full_messages).to include('Statement file not found')
      end
    end

    context 'with transaction type filter' do
      it 'filters by income transactions' do
        result = described_class.call(user, { transaction_type: 'income' })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction2)
        expect(result.payload[:transactions]).not_to include(transaction1, transaction3)
      end

      it 'filters by variable expense transactions' do
        result = described_class.call(user, { transaction_type: 'variable_expense' })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1)
        expect(result.payload[:transactions]).not_to include(transaction2, transaction3)
      end

      it 'filters by fixed expense transactions' do
        result = described_class.call(user, { transaction_type: 'fixed_expense' })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction3)
        expect(result.payload[:transactions]).not_to include(transaction1, transaction2)
      end
    end

    context 'with date range filter' do
      it 'filters by from_date' do
        result = described_class.call(user, { from_date: '2024-03-16' })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction2, transaction3)
        expect(result.payload[:transactions]).not_to include(transaction1)
      end

      it 'filters by to_date' do
        result = described_class.call(user, { to_date: '2024-03-16' })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1, transaction2)
        expect(result.payload[:transactions]).not_to include(transaction3)
      end

      it 'filters by date range' do
        result = described_class.call(user, {
          from_date: '2024-03-16',
          to_date: '2024-03-16'
        })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction2)
        expect(result.payload[:transactions]).not_to include(transaction1, transaction3)
      end
    end

    context 'with sorting' do
      it 'sorts by date descending by default' do
        result = described_class.call(user, {})

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end

      it 'sorts by date ascending' do
        result = described_class.call(user, { sort: 'date', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first).to eq(transaction1)  # Oldest
        expect(transactions.last).to eq(transaction3)   # Most recent
      end

      it 'sorts by amount descending' do
        result = described_class.call(user, { sort: 'amount', direction: 'desc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first).to eq(transaction2)  # Highest amount (2500.00)
        expect(transactions.last).to eq(transaction3)   # Lowest amount (-100.00)
      end

      it 'sorts by amount ascending' do
        result = described_class.call(user, { sort: 'amount', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first).to eq(transaction3)  # Lowest amount (-100.00)
        expect(transactions.last).to eq(transaction2)   # Highest amount (2500.00)
      end

      it 'sorts by description' do
        result = described_class.call(user, { sort: 'description', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first.description).to eq('Rent payment')
        expect(transactions.last.description).to eq('Salary deposit')
      end

      it 'sorts by transaction type' do
        result = described_class.call(user, { sort: 'transaction_type', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first.transaction_type).to eq('fixed_expense')
        expect(transactions.last.transaction_type).to eq('variable_expense')
      end

      it 'sorts by category name' do
        result = described_class.call(user, { sort: 'category', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        # All transactions have the same category, so order should be preserved
        expect(transactions.count).to eq(3)
      end

      it 'sorts by merchant' do
        transaction1.update!(merchant: 'Z Restaurant')
        transaction2.update!(merchant: 'A Company')
        transaction3.update!(merchant: 'M Store')

        result = described_class.call(user, { sort: 'merchant', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first.merchant).to eq('A Company')
        expect(transactions.last.merchant).to eq('Z Restaurant')
      end

      it 'sorts by bank account name' do
        bank.update!(name: 'Z Bank')

        result = described_class.call(user, { sort: 'bank_account', direction: 'asc' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.count).to eq(3)
      end

      it 'falls back to date descending for invalid sort field' do
        result = described_class.call(user, { sort: 'invalid_field' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions.first).to eq(transaction3) # Most recent
        expect(transactions.last).to eq(transaction1)  # Oldest
      end
    end

    context 'with search parameters' do
      it 'searches transactions by description' do
        result = described_class.call(user, { search: 'restaurant' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1)
        expect(transactions).not_to include(transaction2, transaction3)
      end

      it 'performs case-insensitive search' do
        result = described_class.call(user, { search: 'RESTAURANT' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1)
        expect(transactions).not_to include(transaction2, transaction3)
      end

      it 'performs partial matching' do
        result = described_class.call(user, { search: 'rest' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1)
        expect(transactions).not_to include(transaction2, transaction3)
      end

      it 'returns all transactions when search is empty' do
        result = described_class.call(user, { search: '' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1, transaction2, transaction3)
      end

      it 'returns all transactions when search is nil' do
        result = described_class.call(user, { search: nil })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1, transaction2, transaction3)
      end

      it 'returns empty result when no matches found' do
        result = described_class.call(user, { search: 'nonexistent' })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to be_empty
      end
    end

    context 'with combined filters' do
      it 'applies multiple filters correctly' do
        result = described_class.call(user, {
          transaction_type: 'variable_expense',
          from_date: '2024-03-15',
          to_date: '2024-03-15'
        })

        expect(result.success?).to be true
        expect(result.payload[:transactions]).to include(transaction1)
        expect(result.payload[:transactions]).not_to include(transaction2, transaction3)
      end

      it 'applies search with other filters' do
        result = described_class.call(user, {
          search: 'payment',
          transaction_type: 'variable_expense'
        })

        expect(result.success?).to be true
        transactions = result.payload[:transactions]
        expect(transactions).to include(transaction1)
        expect(transactions).not_to include(transaction2, transaction3)
      end
    end

    context 'error handling' do
      it 'handles database errors gracefully' do
        allow(user.transactions).to receive(:includes).and_raise(ActiveRecord::StatementInvalid.new("Database error"))

        result = described_class.call(user, {})

        expect(result.success?).to be false
        expect(result.errors.full_messages).to include(/Failed to load transactions/)
      end
    end

    context 'response structure' do
      it 'returns properly structured response' do
        result = described_class.call(user, {})

        expect(result.success?).to be true
        payload = result.payload

        expect(payload).to have_key(:transactions)
        expect(payload).to have_key(:filtered_transactions)
        expect(payload).to have_key(:statement_file)
        expect(payload).to have_key(:current_sort)
        expect(payload).to have_key(:current_direction)

        expect(payload[:transactions]).to be_a(ActiveRecord::Relation)
        expect(payload[:filtered_transactions]).to be_a(ActiveRecord::Relation)
        expect(payload[:statement_file]).to be_nil
        expect(payload[:current_sort]).to eq('date')
        expect(payload[:current_direction]).to eq('desc')
      end
    end
  end
end
