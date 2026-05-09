# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Destroy", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:auth_headers) do
    {
      "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}"
    }
  end

  describe "DELETE /api/v1/statement_files/:id" do
    it "deletes statement file" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      expect {
        delete "/api/v1/statement_files/#{statement_file.id}", headers: auth_headers
      }.to change(StatementFile, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "deletes associated statement_file-sourced transactions" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)
      statement_transaction = create(
        :transaction,
        user: user,
        bank_account: bank_account,
        statement_file: statement_file,
        source: :statement_file
      )

      expect {
        delete "/api/v1/statement_files/#{statement_file.id}", headers: auth_headers
      }.to change(Transaction, :count).by(-1)
    end

    it "removes statement_file_id from manual transactions without deleting them" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)
      manual_transaction = create(
        :transaction,
        user: user,
        bank_account: bank_account,
        statement_file: statement_file,
        source: :manual
      )

      expect {
        delete "/api/v1/statement_files/#{statement_file.id}", headers: auth_headers
      }.not_to change(Transaction, :count)

      manual_transaction.reload
      expect(manual_transaction.statement_file_id).to be_nil
    end

    it "returns 404 for non-existent statement file" do
      delete "/api/v1/statement_files/99999", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for other user's statement file" do
      other_bank_account = create(:bank_account, user: other_user)
      other_statement = create(:statement_file, user: other_user, bank_account: other_bank_account)

      delete "/api/v1/statement_files/#{other_statement.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      delete "/api/v1/statement_files/#{statement_file.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
