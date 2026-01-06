# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Index", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v1/transactions" do
    let!(:transactions) do
      [
        create(
          :transaction, user: user, bank_account: bank_account, category: category,
          amount: -50.0, transaction_type: "variable_expense", date: Date.current,
          description: "Groceries", source: :manual
        ),
        create(
          :transaction, user: user, bank_account: bank_account, category: category,
          amount: 100.0, transaction_type: "income", date: Date.current - 1.day,
          description: "Salary", source: :manual
        )
      ]
    end

    it "returns transactions list with metadata" do
      get "/api/v1/transactions", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["transactions"].length).to eq(2)
      expect(json["meta"]["pagination"]["total_items"]).to eq(2)
    end

    it "filters by transaction_type" do
      get "/api/v1/transactions?transaction_type=income", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["transactions"].length).to eq(1)
      expect(json["data"]["transactions"].first["transaction_type"]).to eq("income")
    end

    it "supports search and sorting" do
      get "/api/v1/transactions?search=Groceries&sort=amount", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["transactions"].length).to eq(1)
      expect(json["data"]["transactions"].first["description"]).to include("Groceries")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/transactions"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
