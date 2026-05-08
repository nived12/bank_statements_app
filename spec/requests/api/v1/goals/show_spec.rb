# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Goals - Show", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:goal) { create(:goal, :savings_goal, user: user, name: "Vacation Fund") }

  describe "GET /api/v1/goals/:id" do
    it "returns the goal details" do
      get "/api/v1/goals/#{goal.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(goal.id)
      expect(json["data"]["name"]).to eq("Vacation Fund")
      expect(json["data"]["goal_type"]).to eq("savings_goal")
    end

    it "includes computed fields" do
      get "/api/v1/goals/#{goal.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["progress_percentage"]).to be_present
      expect(json["data"]["amount_remaining"]).not_to be_nil
      expect(json["data"]["days_remaining"]).not_to be_nil
      expect(json["data"]["monthly_contribution_needed"]).not_to be_nil
      expect(json["data"]["on_track"]).not_to be_nil
    end

    it "includes associated savings and debts arrays" do
      get "/api/v1/goals/#{goal.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["savings"]).to be_an(Array)
      expect(json["data"]["debts"]).to be_an(Array)
    end

    it "returns 404 for non-existent goal" do
      get "/api/v1/goals/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's goal" do
      other_user = create(:user, :consented)
      other_goal = create(:goal, :savings_goal, user: other_user)

      get "/api/v1/goals/#{other_goal.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/goals/#{goal.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
