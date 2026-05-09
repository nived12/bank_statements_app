# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Debts - Index", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/debts" do
    let!(:active_debt) { create(:debt, user: user, name: "Credit Card", status: :active) }
    let!(:paid_off_debt) { create(:debt, user: user, name: "Car Loan", status: :paid_off, current_balance: 0) }
    let!(:paused_debt) { create(:debt, user: user, name: "Student Loan", status: :paused) }

    it "returns all debts by default" do
      get "/api/v1/debts", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["debts"].length).to eq(3)
    end

    it "filters debts by status" do
      get "/api/v1/debts", params: { status: "active" }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["debts"].length).to eq(1)
      expect(json["data"]["debts"][0]["name"]).to eq("Credit Card")
      expect(json["data"]["debts"][0]["status"]).to eq("active")
    end

    it "includes progress information" do
      get "/api/v1/debts", headers: auth_headers
      json = JSON.parse(response.body)

      debt = json["data"]["debts"].first
      expect(debt["progress_percentage"]).to be_present
      expect(debt["amount_remaining"]).to be_present
      expect(debt["amount_paid"]).to be_present
      expect(debt["original_amount"]).to be_present
      expect(debt["current_balance"]).to be_present
    end

    it "includes associated goals, categories, and bank accounts" do
      goal = create(:goal, user: user, goal_type: :debt_payoff, debt_strategy: "avalanche")
      category = create(:category, user: user, name: "Expenses")
      bank_account = create(:bank_account, user: user)

      debt = create(:debt, user: user, name: "Mortgage")
      debt.goals << goal
      debt.categories << category
      debt.bank_accounts << bank_account

      get "/api/v1/debts", headers: auth_headers
      json = JSON.parse(response.body)

      mortgage_debt = json["data"]["debts"].find { |d| d["name"] == "Mortgage" }
      expect(mortgage_debt["goals"].length).to eq(1)
      expect(mortgage_debt["goals"][0]["name"]).to eq(goal.name)
      expect(mortgage_debt["categories"].length).to eq(1)
      expect(mortgage_debt["categories"][0]["name"]).to eq("Expenses")
      expect(mortgage_debt["bank_accounts"].length).to eq(1)
    end

    it "includes pagination metadata" do
      get "/api/v1/debts", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["meta"]["pagination"]).to be_present
      expect(json["meta"]["pagination"]["current_page"]).to eq(1)
      expect(json["meta"]["pagination"]["total_pages"]).to be >= 1
      expect(json["meta"]["pagination"]["total_items"]).to eq(3)
    end

    it "supports pagination with page parameter" do
      get "/api/v1/debts", params: { page: 1, page_size: 2 }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["debts"].length).to eq(2)
      expect(json["meta"]["pagination"]["page_size"]).to eq(2)
    end

    it "does not include archived debts" do
      archived = create(:debt, user: user, name: "Archived", status: :archived)
      archived.discard

      get "/api/v1/debts", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["debts"].map { |d| d["name"] }).not_to include("Archived")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/debts"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
