require 'rails_helper'

RSpec.describe Transactions::ProcessDuplicatesService, type: :service do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(user, statement_file.id, selected_transaction_ids) }

  describe '#call' do
    context 'when processing duplicates successfully' do
      let(:selected_transaction_ids) { [ pending_transaction.id.to_s ] }
      let(:pending_transaction) do
        create(:pending_transaction,
               statement_file: statement_file,
               user: user,
               bank_account: bank_account,
               source: :statement_file)
      end

      before do
        # Create another pending transaction that won't be selected
        create(:pending_transaction,
               statement_file: statement_file,
               user: user,
               bank_account: bank_account,
               source: :manual)
      end

      it 'creates transactions from selected pending transactions' do
        expect { service.call }.to change(Transaction, :count).by(1)
      end

      it 'marks statement file as completed' do
        service.call
        expect(statement_file.reload.status).to eq('completed')
      end

      it 'cleans up pending transactions' do
        service.call
        expect(PendingTransaction.where(statement_file: statement_file).count).to eq(0)
      end

      it 'returns success with processed count' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload[:processed_count]).to eq(1)
      end
    end

    context 'when processing manual transactions' do
      let(:selected_transaction_ids) { [ pending_transaction.id.to_s ] }
      let(:pending_transaction) do
        create(:pending_transaction,
               statement_file: statement_file,
               user: user,
               bank_account: bank_account,
               source: :manual)
      end

      let!(:original_transaction) do
        create(:transaction,
               user: user,
               bank_account: bank_account,
               date: pending_transaction.date,
               amount: pending_transaction.amount,
               description: pending_transaction.description,
               source: :manual)
      end

      it 'keeps the original manual transaction and links it to statement file' do
        expect { service.call }.to change(Transaction, :count).by(0)
        expect(Transaction.find_by(id: original_transaction.id)).to be_present
        expect(original_transaction.reload.statement_file).to eq(statement_file)
      end
    end

    context 'when no transactions are selected' do
      let(:selected_transaction_ids) { [] }

      before do
        create(:pending_transaction,
               statement_file: statement_file,
               user: user,
               bank_account: bank_account)
      end

      it 'still marks statement file as completed' do
        service.call
        expect(statement_file.reload.status).to eq('completed')
      end

      it 'cleans up pending transactions' do
        service.call
        expect(PendingTransaction.where(statement_file: statement_file).count).to eq(0)
      end
    end
  end

  describe '#group_pending_transactions' do
    let(:selected_transaction_ids) { [] }
    let(:date) { Date.current }
    let(:amount) { 100.00 }

    before do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: date,
             amount: amount)

      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: date,
             amount: amount)
    end

    it 'groups transactions by duplicate criteria' do
      pending_transactions = statement_file.pending_transactions
      groups = service.send(:group_pending_transactions, pending_transactions)
      expect(groups.length).to eq(1)
      expect(groups.first.length).to eq(2)
    end
  end
end
