# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Goals - Index", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/goals" do
    let!(:active_savings_goal) { create(:goal, :savings_goal, user: user, name: "Vacation Fund", status: "active") }
    let!(:completed_savings_goal) do
      create(:goal, :savings_goal, user: user, name: "Emergency Fund", status: "completed")
    end
    let!(:active_debt_goal) { create(:goal, :debt_payoff, user: user, name: "Pay Off Card", status: "active") }

    it "returns all goals by default" do
      get "/api/v1/goals", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["goals"].length).to eq(3)
    end

    it "filters goals by status" do
      get "/api/v1/goals", params: { status: "active" }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["goals"].length).to eq(2)
      expect(json["data"]["goals"].map { |g| g["status"] }).to all(eq("active"))
    end

    it "filters goals by goal_type" do
      get "/api/v1/goals", params: { goal_type: "debt_payoff" }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["goals"].length).to eq(1)
      expect(json["data"]["goals"][0]["goal_type"]).to eq("debt_payoff")
    end

    it "includes progress information" do
      get "/api/v1/goals", headers: auth_headers
      json = JSON.parse(response.body)

      goal = json["data"]["goals"].first
      expect(goal["progress_percentage"]).to be_present
      expect(goal["amount_remaining"]).to be_present
      expect(goal["days_remaining"]).to be_present
      expect(goal["on_track"]).not_to be_nil
    end

    it "includes pagination metadata" do
      get "/api/v1/goals", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["meta"]["pagination"]).to be_present
      expect(json["meta"]["pagination"]["current_page"]).to eq(1)
      expect(json["meta"]["pagination"]["total_pages"]).to be >= 1
      expect(json["meta"]["pagination"]["total_items"]).to eq(3)
    end

    it "supports pagination with page parameter" do
      get "/api/v1/goals", params: { page: 1, page_size: 2 }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["goals"].length).to eq(2)
      expect(json["meta"]["pagination"]["page_size"]).to eq(2)
    end

    it "does not include discarded goals" do
      discarded_goal = create(:goal, :savings_goal, user: user, name: "Archived Goal")
      discarded_goal.discard

      get "/api/v1/goals", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["goals"].map { |g| g["name"] }).not_to include("Archived Goal")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/goals"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
