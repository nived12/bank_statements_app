# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Destroy", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "DELETE /api/v1/transactions/:id" do
    let!(:transaction) do
      create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual)
    end

    it "deletes transaction successfully" do
      expect {
        delete "/api/v1/transactions/#{transaction.id}", headers: auth_headers
      }.to change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:success)
    end

    it "deletes statement file transactions" do
      statement_transaction = create(
        :transaction, user: user, bank_account: bank_account, category: category,
        source: :statement_file
      )

      expect {
        delete "/api/v1/transactions/#{statement_transaction.id}", headers: auth_headers
      }.to change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:success)
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/transactions/#{transaction.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
