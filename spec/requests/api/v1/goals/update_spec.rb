# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Goals - Update", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:goal) { create(:goal, :savings_goal, user: user, name: "Vacation Fund") }

  describe "PATCH /api/v1/goals/:id" do
    let(:update_params) do
      {
        goal: {
          name: "Updated Vacation Fund",
          notes: "Saving for Europe trip",
          color: "#10B981"
        }
      }
    end

    it "updates the goal" do
      patch "/api/v1/goals/#{goal.id}", params: update_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["name"]).to eq("Updated Vacation Fund")
      expect(json["data"]["notes"]).to eq("Saving for Europe trip")
      expect(json["data"]["color"]).to eq("#10B981")
      expect(json["message"]).to eq("Goal updated successfully")
    end

    it "updates savings associations via saving_ids" do
      saving = create(:saving, user: user)

      patch "/api/v1/goals/#{goal.id}",
        params: { goal: { saving_ids: [saving.id] } },
        headers: auth_headers

      expect(response).to have_http_status(:success)
      goal.reload
      expect(goal.savings).to include(saving)
    end

    it "handles validation errors" do
      patch "/api/v1/goals/#{goal.id}",
        params: { goal: { name: "AB" } },
        headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "returns 404 for non-existent goal" do
      patch "/api/v1/goals/999999", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's goal" do
      other_user = create(:user)
      other_goal = create(:goal, :savings_goal, user: other_user)

      patch "/api/v1/goals/#{other_goal.id}", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/goals/#{goal.id}", params: update_params
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
