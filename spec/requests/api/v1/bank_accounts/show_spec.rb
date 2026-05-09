# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Show", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/bank_accounts/:id" do
    let(:bank) { create(:bank, name: "Test Bank", code: "test") }
    let(:bank_account) { create(:bank_account, user: user, bank: bank, custom_name: "Savings Account") }

    it "returns bank account details" do
      get "/api/v1/bank_accounts/#{bank_account.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(bank_account.id)
      expect(json["data"]["custom_name"]).to eq("Savings Account")
      expect(json["data"]["account_number"]).to eq(bank_account.account_number)
    end

    it "includes bank information" do
      get "/api/v1/bank_accounts/#{bank_account.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["bank"]).to be_present
      expect(json["data"]["bank"]["id"]).to eq(bank.id)
      expect(json["data"]["bank"]["code"]).to eq("test")
      expect(json["data"]["bank"]["name"]).to eq("Test Bank")
    end

    it "returns 404 for non-existent bank account" do
      get "/api/v1/bank_accounts/999999", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:not_found)
      expect(json["error"]["code"]).to eq("NOT_FOUND")
    end

    it "returns 404 when accessing another user's bank account" do
      other_user = create(:user)
      other_bank_account = create(:bank_account, user: other_user, bank: bank)

      get "/api/v1/bank_accounts/#{other_bank_account.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/bank_accounts/#{bank_account.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
