# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v1/transactions" do
    let!(:transactions) do
      [
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: -50.0, transaction_type: "variable_expense", date: Date.current,
               description: "Groceries", source: :manual),
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: 100.0, transaction_type: "income", date: Date.current - 1.day,
               description: "Salary", source: :manual)
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

  describe "GET /api/v1/transactions/:id" do
    let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

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

  describe "POST /api/v1/transactions" do
    let(:valid_params) do
      {
        transaction: {
          bank_account_id: bank_account.id,
          date: Date.current.to_s,
          description: "Test transaction",
          amount: 100.50,
          transaction_type: "income",
          category_id: category.id
        }
      }
    end

    it "creates a new transaction successfully" do
      expect {
        post "/api/v1/transactions", params: valid_params, headers: auth_headers, as: :json
      }.to change(Transaction, :count).by(1)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["amount"]).to eq(100.50)
      expect(json["data"]["source"]).to eq("manual")
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/transactions", params: { transaction: { description: "ab" } }, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/transactions", params: { transaction: {} }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/transactions/:id" do
    let(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual, amount: 50.0) }

    it "updates transaction successfully" do
      patch "/api/v1/transactions/#{transaction.id}",
            params: { transaction: { description: "Updated", amount: 75.0 } },
            headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["description"]).to eq("Updated")
      expect(json["data"]["amount"]).to eq(-75.0)
    end

    it "prevents updating statement file transactions" do
      statement_transaction = create(:transaction, user: user, bank_account: bank_account, category: category, source: :statement_file)

      patch "/api/v1/transactions/#{statement_transaction.id}",
            params: { transaction: { description: "New" } },
            headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("UPDATE_NOT_ALLOWED")
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: {} }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/transactions/:id" do
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

    it "deletes transaction successfully" do
      expect {
        delete "/api/v1/transactions/#{transaction.id}", headers: auth_headers
      }.to change(Transaction, :count).by(-1)

      expect(response).to have_http_status(:success)
    end

    it "prevents deleting statement file transactions" do
      statement_transaction = create(:transaction, user: user, bank_account: bank_account, category: category, source: :statement_file)

      expect {
        delete "/api/v1/transactions/#{statement_transaction.id}", headers: auth_headers
      }.not_to change(Transaction, :count)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("DESTROY_NOT_ALLOWED")
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/transactions/#{transaction.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/transactions/summary" do
    let!(:transactions) do
      [
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: 1000.0, transaction_type: "income", source: :manual),
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: -250.0, transaction_type: "variable_expense", source: :manual)
      ]
    end

    it "returns transaction summary with correct statistics" do
      get "/api/v1/transactions/summary", headers: auth_headers
      json = JSON.parse(response.body)
      stats = json["data"]["stats"]

      expect(response).to have_http_status(:success)
      expect(stats["total_transactions"]).to eq(2)
      expect(stats["income_total"]).to eq(1000.0)
      expect(stats["expenses_total"]).to eq(-250.0)
      expect(stats["equity_total"]).to eq(750.0)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/transactions/summary"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
