# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Show", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v1/transactions/:id" do
    let(:transaction) {
 create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

    it "returns transaction details with associations" do
      get "/api/v1/transactions/#{transaction.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(transaction.id)
      expect(json["data"]["bank_account"]["id"]).to eq(bank_account.id)
      expect(json["data"]["category"]["id"]).to eq(category.id)
    end

    it "returns 404 for non-existent transaction" do
      get "/api/v1/transactions/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/transactions/#{transaction.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
