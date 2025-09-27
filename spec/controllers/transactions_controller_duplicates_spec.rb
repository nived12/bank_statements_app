require 'rails_helper'

RSpec.describe TransactionsController, type: :controller do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, status: :parsed) }

  before do
    sign_in_user_with_locale(user)
  end

  describe 'GET #check_duplicates' do
    context 'when there are no duplicates' do
      it 'returns empty response' do
        get :check_duplicates
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['has_duplicates']).to be false
        expect(json_response['statement_files']).to eq([])
      end
    end

    context 'when there are duplicates' do
      before do
        create(:pending_transaction,
               statement_file: statement_file,
               user: user,
               bank_account: bank_account)
      end

      it 'returns statement files with duplicates' do
        get :check_duplicates
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['has_duplicates']).to be true
        expect(json_response['statement_files'].length).to eq(1)
        expect(json_response['statement_files'].first['id']).to eq(statement_file.id)
      end
    end
  end

  describe 'GET #get_duplicates' do
    let(:pending_transaction1) do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: Date.current,
             amount: 100.00,
             source: :manual)
    end

    let(:pending_transaction2) do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             date: Date.current,
             amount: 100.00,
             source: :statement_file)
    end

    before do
      pending_transaction1
      pending_transaction2
    end

    it 'returns duplicates grouped by criteria' do
      get :get_duplicates, params: { statement_file_id: statement_file.id }
      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['statement_file']['id']).to eq(statement_file.id)
      expect(json_response['duplicates'].length).to eq(1)
      expect(json_response['duplicates'].first['transactions'].length).to eq(2)
    end
  end

  describe 'POST #process_duplicates' do
    let(:pending_transaction) do
      create(:pending_transaction,
             statement_file: statement_file,
             user: user,
             bank_account: bank_account,
             source: :statement_file)
    end

    let(:selected_transaction_ids) { [ pending_transaction.id.to_s ] }

    it 'processes selected duplicates successfully' do
      post :process_duplicates, params: {
        statement_file_id: statement_file.id,
        selected_transaction_ids: selected_transaction_ids
      }

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['processed_count']).to eq(1)
    end

    it 'marks statement file as completed' do
      post :process_duplicates, params: {
        statement_file_id: statement_file.id,
        selected_transaction_ids: selected_transaction_ids
      }

      expect(statement_file.reload.status).to eq('completed')
    end

    it 'cleans up pending transactions' do
      post :process_duplicates, params: {
        statement_file_id: statement_file.id,
        selected_transaction_ids: selected_transaction_ids
      }

      expect(PendingTransaction.where(statement_file: statement_file).count).to eq(0)
    end

    context 'when service fails' do
      before do
        allow(Transactions::ProcessDuplicatesService).to receive(:call).and_return(
          double(success?: false, errors: double(full_messages: [ 'Error message' ]))
        )
      end

      it 'returns error response' do
        post :process_duplicates, params: {
          statement_file_id: statement_file.id,
          selected_transaction_ids: selected_transaction_ids
        }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Error message')
      end
    end
  end
end
