# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Index", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user, name: "Food") }
  let(:other_category) { create(:category, user: user, name: "Transport") }

  describe "GET /api/v1/transactions" do
    let!(:food_transaction) do
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        amount: -50.0, transaction_type: "variable_expense", date: Date.current,
        description: "Groceries", source: :manual, concept: "Weekly grocery run"
      )
    end

    let!(:income_transaction) do
      create(
        :transaction, user: user, bank_account: bank_account, category: other_category,
        amount: 100.0, transaction_type: "income", date: Date.current - 1.day,
        description: "Salary", source: :manual
      )
    end

    it "returns transactions list with metadata" do
      get "/api/v1/transactions", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["transactions"].length).to eq(2)
      expect(json["meta"]["pagination"]["total_items"]).to eq(2)
    end

    it "returns concept field in each transaction" do
      get "/api/v1/transactions", headers: auth_headers
      json = JSON.parse(response.body)

      tx = json["data"]["transactions"].find { |t| t["description"] == "Groceries" }
      expect(tx).to have_key("concept")
      expect(tx["concept"]).to eq("Weekly grocery run")
    end

    it "returns statement_file_id field in each transaction" do
      get "/api/v1/transactions", headers: auth_headers
      json = JSON.parse(response.body)

      tx = json["data"]["transactions"].first
      expect(tx).to have_key("statement_file_id")
    end

    it "filters by transaction_type" do
      get "/api/v1/transactions?transaction_type=income", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["transactions"].length).to eq(1)
      expect(json["data"]["transactions"].first["transaction_type"]).to eq("income")
    end

    it "filters by category_id" do
      get "/api/v1/transactions", params: { category_id: category.id }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["transactions"].length).to eq(1)
      expect(json["data"]["transactions"].first["description"]).to eq("Groceries")
    end

    it "returns all transactions when category_id does not match" do
      get "/api/v1/transactions", params: { category_id: 999_999 }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["transactions"]).to be_empty
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
