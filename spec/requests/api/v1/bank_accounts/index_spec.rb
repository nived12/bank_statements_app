# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Index", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/bank_accounts" do
    let!(:bank1) { create(:bank, name: "Test Bank 1", code: "test1") }
    let!(:bank2) { create(:bank, name: "Test Bank 2", code: "test2") }
    let!(:bank_account1) { create(:bank_account, user: user, bank: bank1, custom_name: "Savings Account") }
    let!(:bank_account2) { create(:bank_account, user: user, bank: bank2, custom_name: "Checking Account") }

    it "returns all bank accounts for the authenticated user" do
      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["bank_accounts"].length).to eq(2)
    end

    it "includes bank information in the response" do
      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      bank_account = json["data"]["bank_accounts"].first
      expect(bank_account["bank"]).to be_present
      expect(bank_account["bank"]["id"]).to be_present
      expect(bank_account["bank"]["code"]).to be_present
      expect(bank_account["bank"]["name"]).to be_present
    end

    it "includes display_name in the response" do
      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      bank_account = json["data"]["bank_accounts"].first
      expect(bank_account["display_name"]).to be_present
    end

    it "includes transactions_count in the response" do
      create(:transaction, user: user, bank_account: bank_account1, source: :manual)

      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      bank_account = json["data"]["bank_accounts"].find { |ba| ba["id"] == bank_account1.id }
      expect(bank_account["transactions_count"]).to eq(1)
    end

    it "does not return bank accounts from other users" do
      other_user = create(:user, :confirmed)
      create(:bank_account, user: other_user, bank: bank1)

      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["bank_accounts"].length).to eq(2)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/bank_accounts"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
