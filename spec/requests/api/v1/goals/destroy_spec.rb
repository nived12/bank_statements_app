# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Goals - Destroy", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:goal) { create(:goal, :savings_goal, user: user, name: "Vacation Fund") }

  describe "DELETE /api/v1/goals/:id" do
    it "soft deletes the goal" do
      delete "/api/v1/goals/#{goal.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Goal.kept.find_by(id: goal.id)).to be_nil
      expect(Goal.with_discarded.find_by(id: goal.id)).to be_present
    end

    it "sets the goal status to archived after discard" do
      delete "/api/v1/goals/#{goal.id}", headers: auth_headers

      goal.reload
      expect(goal.status).to eq("archived")
    end

    it "returns 404 for non-existent goal" do
      delete "/api/v1/goals/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's goal" do
      other_user = create(:user, :confirmed)
      other_goal = create(:goal, :savings_goal, user: other_user)

      delete "/api/v1/goals/#{other_goal.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/goals/#{goal.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
