# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Destroy", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "DELETE /api/v1/bank_accounts/:id" do
    let(:bank) { create(:bank, name: "Test Bank", code: "test") }
    let(:bank_account) { create(:bank_account, user: user, bank: bank) }

    it "deletes bank account successfully" do
      bank_account_id = bank_account.id
      initial_count = user.bank_accounts.count

      delete "/api/v1/bank_accounts/#{bank_account_id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(user.bank_accounts.count).to eq(initial_count - 1)
      expect(BankAccount.exists?(bank_account_id)).to be_falsey
    end

    it "deletes associated transactions when bank account is deleted" do
      transaction = create(:transaction, user: user, bank_account: bank_account, source: :manual)

      delete "/api/v1/bank_accounts/#{bank_account.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Transaction.exists?(transaction.id)).to be_falsey
    end

    it "returns 404 for non-existent bank account" do
      delete "/api/v1/bank_accounts/999999", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:not_found)
      expect(json["error"]["code"]).to eq("NOT_FOUND")
    end

    it "returns 404 when deleting another user's bank account" do
      other_user = create(:user, :confirmed)
      other_bank_account = create(:bank_account, user: other_user, bank: bank)

      delete "/api/v1/bank_accounts/#{other_bank_account.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/bank_accounts/#{bank_account.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
