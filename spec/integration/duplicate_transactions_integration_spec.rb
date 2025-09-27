require 'rails_helper'

RSpec.describe 'Duplicate Transactions Integration', type: :feature do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

  before do
    sign_in_user_with_locale(user)
  end

  describe 'Complete duplicate detection and processing flow' do
    context 'when a statement file has duplicate transactions' do
      let(:existing_transaction) do
        create(:transaction,
               user: user,
               bank_account: bank_account,
               date: Date.parse('2024-01-15'),
               description: 'Test Transaction',
               amount: 100.00,
               source: :manual)
      end

      let(:parsed_json) do
        {
          "transactions" => [
            {
              "date" => "2024-01-15",
              "description" => "Test Transaction",
              "amount" => "100.00",
              "transaction_type" => "variable_expense",
              "bank_entry_type" => "debit"
            }
          ]
        }
      end

      before do
        existing_transaction
        statement_file.update(parsed_json: parsed_json)
      end

      it 'detects duplicates and stores them in PendingTransactions' do
        # Simulate the importer detecting duplicates
        importer = Transactions::Importer.new(statement_file)
        result = importer.call

        expect(result.success?).to be true
        expect(result.payload[:duplicates_found]).to be true

        # Check that pending transactions were created
        pending_transactions = statement_file.pending_transactions
        expect(pending_transactions.count).to eq(2) # One manual, one statement_file

        # Check that statement file status remains unchanged (importer doesn't change status)
        expect(statement_file.reload.status).to eq('pending')
      end

      it 'allows user to process duplicates through the API' do
        # First, create the pending transactions
        importer = Transactions::Importer.new(statement_file)
        importer.call

        # Get the pending transactions
        pending_transactions = statement_file.pending_transactions
        manual_pending = pending_transactions.find_by(source: :manual)
        statement_file_pending = pending_transactions.find_by(source: :statement_file)

        # Process duplicates (select the manual one)
        process_service = Transactions::ProcessDuplicatesService.new(
          user,
          statement_file.id,
          [ manual_pending.id.to_s ]
        )
        result = process_service.call

        expect(result.success?).to be true
        expect(result.payload[:processed_count]).to eq(1)

        # Check that the manual transaction was kept and linked to statement file
        expect(Transaction.where(source: :manual).count).to eq(1)
        expect(Transaction.find_by(id: existing_transaction.id)).to be_present
        expect(existing_transaction.reload.statement_file).to eq(statement_file)

        # Check that statement file is marked as completed
        expect(statement_file.reload.status).to eq('completed')

        # Check that pending transactions are cleaned up
        expect(PendingTransaction.where(statement_file: statement_file).count).to eq(0)
      end
    end

    context 'when statement file has no duplicates' do
      let(:parsed_json) do
        {
          "transactions" => [
            {
              "date" => "2024-01-15",
              "description" => "Unique Transaction",
              "amount" => "100.00",
              "transaction_type" => "variable_expense",
              "bank_entry_type" => "debit"
            }
          ]
        }
      end

      before do
        statement_file.update(parsed_json: parsed_json)
      end

      it 'imports transactions normally and marks as completed' do
        importer = Transactions::Importer.new(statement_file)
        result = importer.call

        expect(result.success?).to be true
        expect(result.payload[:duplicates_found]).to be false

        # Check that transaction was created
        expect(Transaction.count).to eq(1)
        expect(Transaction.first.source).to eq('statement_file')

        # Check that statement file status remains unchanged (importer doesn't change status)
        expect(statement_file.reload.status).to eq('pending')

        # Check that no pending transactions were created
        expect(PendingTransaction.count).to eq(0)
      end
    end
  end

  describe 'Statement file deletion behavior' do
    let!(:manual_transaction) do
      create(:transaction,
             user: user,
             bank_account: bank_account,
             statement_file: statement_file,
             source: :manual)
    end

    let!(:statement_file_transaction) do
      create(:transaction,
             user: user,
             bank_account: bank_account,
             statement_file: statement_file,
             source: :statement_file)
    end

    it 'handles transaction cleanup correctly when statement file is deleted' do
      expect(Transaction.count).to eq(2)

      # Delete the statement file
      result = statement_file.destroy

      # Check the result - it should be false due to dependent: :restrict_with_error
      expect(result).to be false
      expect(statement_file.errors[:base]).to include("No se puede eliminar el registro porque existen transactions dependientes")

      # Check that both transactions still exist (deletion was prevented)
      expect(Transaction.count).to eq(2)
      expect(Transaction.where(source: :manual).count).to eq(1)
      expect(Transaction.where(source: :statement_file).count).to eq(1)
    end
  end
end
