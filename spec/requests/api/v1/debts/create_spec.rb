# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Debts - Create", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }

  describe "POST /api/v1/debts" do
    let(:valid_params) do
      {
        debt: {
          name: "Credit Card Debt",
          original_amount: 5000,
          current_balance: 3000,
          interest_rate: 18.5,
          minimum_payment: 100,
          color: "#FF5733",
          icon: "💳",
          status: "active",
          notes: "Chase credit card",
          payment_mode: "fixed",
          payment_frequency: "monthly",
          target_payment_amount: 300,
          due_day_of_month: 15,
          category_ids: [category.id],
          bank_account_ids: [bank_account.id]
        }
      }
    end

    it "creates a new debt" do
      expect {
        post "/api/v1/debts", params: valid_params, headers: auth_headers
      }.to change(Debt, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns the created debt" do
      post "/api/v1/debts", params: valid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["name"]).to eq("Credit Card Debt")
      expect(json["data"]["original_amount"]).to eq(5000.0)
      expect(json["data"]["current_balance"]).to eq(3000.0)
      expect(json["data"]["interest_rate"]).to eq(18.5)
      expect(json["data"]["status"]).to eq("active")
      expect(json["data"]["color"]).to eq("#FF5733")
      expect(json["message"]).to eq("Debt created successfully")
    end

    it "associates categories and bank accounts" do
      post "/api/v1/debts", params: valid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["categories"].length).to eq(1)
      expect(json["data"]["categories"][0]["id"]).to eq(category.id)
      expect(json["data"]["bank_accounts"].length).to eq(1)
      expect(json["data"]["bank_accounts"][0]["id"]).to eq(bank_account.id)
    end

    it "handles validation errors" do
      invalid_params = { debt: { name: "AB" } } # Name too short

      post "/api/v1/debts", params: invalid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to create debt")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "sanitizes money fields (removes commas)" do
      params_with_commas = valid_params.deep_dup
      params_with_commas[:debt][:original_amount] = "5,000"
      params_with_commas[:debt][:current_balance] = "3,000"

      post "/api/v1/debts", params: params_with_commas, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["original_amount"]).to eq(5000.0)
      expect(json["data"]["current_balance"]).to eq(3000.0)
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/debts", params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
