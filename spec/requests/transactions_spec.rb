# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before { sign_in_user(user) }

  describe "GET /transactions" do
    it "renders empty state" do
      get "/transactions"
      expect(response).to have_http_status(:success)
    end

    it "returns JSON with pagination" do
      create_list(:transaction, 3, user: user, bank_account: bank_account, category: category)

      get "/transactions.json"
      json = JSON.parse(response.body)

      expect(json["transactions"].length).to eq(3)
      expect(json["pagination"]["count"]).to eq(3)
    end

    it "filters by transaction type" do
      create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income")
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "fixed_expense"
      )

      get "/transactions.json", params: { transaction_type: "income" }
      json = JSON.parse(response.body)

      expect(json["transactions"].length).to eq(1)
      expect(json["transactions"].first["transaction_type"]).to eq("income")
    end

    it "filters by date range" do
      create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 1, 15))
      recent = create(
        :transaction, user: user, bank_account: bank_account, category: category,
        date: Date.new(2024, 12, 15)
      )

      get "/transactions.json", params: { from_date: "2024-06-01" }
      json = JSON.parse(response.body)

      expect(json["transactions"].map { |t| t["id"] }).to eq([recent.id])
    end

    it "sorts transactions" do
      create(:transaction, user: user, bank_account: bank_account, category: category)

      get "/transactions", params: { sort: "amount" }
      expect(response).to have_http_status(:success)
    end

    it "handles invalid page parameter" do
      get "/transactions", params: { page: "invalid" }
      expect(response).to have_http_status(:success)
    end
  end
end
