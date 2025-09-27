require 'rails_helper'

RSpec.describe PendingTransaction, type: :model do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:category) { create(:category, user: user) }

  describe 'associations' do
    it 'belongs to statement_file' do
      pending_transaction = create(:pending_transaction, statement_file: statement_file)
      expect(pending_transaction.statement_file).to eq(statement_file)
    end

    it 'belongs to user' do
      pending_transaction = create(:pending_transaction, user: user)
      expect(pending_transaction.user).to eq(user)
    end

    it 'belongs to bank_account' do
      pending_transaction = create(:pending_transaction, bank_account: bank_account)
      expect(pending_transaction.bank_account).to eq(bank_account)
    end

    it 'belongs to category optionally' do
      pending_transaction = create(:pending_transaction, category: category)
      expect(pending_transaction.category).to eq(category)
    end
  end

  describe 'validations' do
    it 'validates presence of required fields' do
      pending_transaction = PendingTransaction.new
      expect(pending_transaction.valid?).to be false
      expect(pending_transaction.errors[:date]).to include("no puede estar en blanco")
      expect(pending_transaction.errors[:description]).to include("no puede estar en blanco")
      expect(pending_transaction.errors[:amount]).to include("no puede estar en blanco")
      expect(pending_transaction.errors[:transaction_type]).to include("no puede estar en blanco")
    end

    it 'validates amount is not zero' do
      pending_transaction = build(:pending_transaction, amount: 0)
      expect(pending_transaction.valid?).to be false
      expect(pending_transaction.errors[:amount]).to include("debe ser diferente de 0")
    end

    it 'validates description length' do
      pending_transaction = build(:pending_transaction, description: "abc")
      expect(pending_transaction.valid?).to be false
      expect(pending_transaction.errors[:description]).to include("must be meaningful (at least 4 characters)")
    end
  end

  describe 'enums' do
    it 'has source enum with correct values' do
      expect(PendingTransaction.sources).to eq({ "manual" => 0, "statement_file" => 1 })
    end
  end

  describe 'scopes' do
    let!(:pending_transaction1) do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: Date.current,
             amount: 100.00)
    end

    let!(:pending_transaction2) do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: Date.current,
             amount: 200.00)
    end

    describe '.duplicates_for' do
      it 'finds transactions with matching criteria' do
        duplicates = PendingTransaction.duplicates_for(user.id, bank_account.id, Date.current, 100.00)
        expect(duplicates).to include(pending_transaction1)
        expect(duplicates).not_to include(pending_transaction2)
      end
    end

    describe '.by_statement_file' do
      it 'finds transactions for specific statement file' do
        transactions = PendingTransaction.by_statement_file(statement_file.id)
        expect(transactions).to include(pending_transaction1, pending_transaction2)
      end
    end

    describe '.by_source' do
      before do
        pending_transaction1.update(source: :manual)
        pending_transaction2.update(source: :statement_file)
      end

      it 'finds transactions by source' do
        manual_transactions = PendingTransaction.by_source(:manual)
        statement_file_transactions = PendingTransaction.by_source(:statement_file)

        expect(manual_transactions).to include(pending_transaction1)
        expect(statement_file_transactions).to include(pending_transaction2)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid pending transaction' do
      pending_transaction = create(:pending_transaction,
                                   statement_file: statement_file,
                                   user: user,
                                   bank_account: bank_account)
      expect(pending_transaction).to be_valid
    end
  end
end
