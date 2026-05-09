# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Savings - Index", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/savings" do
    let!(:active_saving) { create(:saving, user: user, name: "Emergency Fund", status: :active) }
    let!(:completed_saving) { create(:saving, user: user, name: "Vacation", status: :completed) }
    let!(:paused_saving) { create(:saving, user: user, name: "Car", status: :paused) }

    it "returns all savings by default" do
      get "/api/v1/savings", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["savings"].length).to eq(3)
    end

    it "filters savings by status" do
      get "/api/v1/savings", params: { status: "active" }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["savings"].length).to eq(1)
      expect(json["data"]["savings"][0]["name"]).to eq("Emergency Fund")
      expect(json["data"]["savings"][0]["status"]).to eq("active")
    end

    it "includes progress information" do
      get "/api/v1/savings", headers: auth_headers
      json = JSON.parse(response.body)

      saving = json["data"]["savings"].first
      expect(saving["progress_percentage"]).to be_present
      expect(saving["amount_remaining"]).to be_present
      expect(saving["target_amount"]).to be_present
      expect(saving["current_amount"]).to be_present
    end

    it "includes associated goals, categories, and bank accounts" do
      goal = create(:goal, user: user, goal_type: :savings_goal)
      category = create(:category, user: user, name: "Income")
      bank_account = create(:bank_account, user: user)

      saving = create(:saving, user: user, name: "House")
      saving.goals << goal
      saving.categories << category
      saving.bank_accounts << bank_account

      get "/api/v1/savings", headers: auth_headers
      json = JSON.parse(response.body)

      house_saving = json["data"]["savings"].find { |s| s["name"] == "House" }
      expect(house_saving["goals"].length).to eq(1)
      expect(house_saving["goals"][0]["name"]).to eq(goal.name)
      expect(house_saving["categories"].length).to eq(1)
      expect(house_saving["categories"][0]["name"]).to eq("Income")
      expect(house_saving["bank_accounts"].length).to eq(1)
    end

    it "includes pagination metadata" do
      get "/api/v1/savings", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["meta"]["pagination"]).to be_present
      expect(json["meta"]["pagination"]["current_page"]).to eq(1)
      expect(json["meta"]["pagination"]["total_pages"]).to be >= 1
      expect(json["meta"]["pagination"]["total_items"]).to eq(3)
    end

    it "supports pagination with page parameter" do
      get "/api/v1/savings", params: { page: 1, page_size: 2 }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["savings"].length).to eq(2)
      expect(json["meta"]["pagination"]["page_size"]).to eq(2)
    end

    it "does not include archived savings" do
      archived = create(:saving, user: user, name: "Archived", status: :archived)
      archived.discard

      get "/api/v1/savings", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["savings"].map { |s| s["name"] }).not_to include("Archived")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/savings"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
