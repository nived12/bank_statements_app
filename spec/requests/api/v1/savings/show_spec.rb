# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Savings - Show", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:saving) { create(:saving, user: user, name: "Emergency Fund") }

  describe "GET /api/v1/savings/:id" do
    it "returns the saving details" do
      get "/api/v1/savings/#{saving.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(saving.id)
      expect(json["data"]["name"]).to eq("Emergency Fund")
      expect(json["data"]["progress_percentage"]).to be_present
      expect(json["data"]["amount_remaining"]).to be_present
    end

    it "includes monthly timeline data" do
      get "/api/v1/savings/#{saving.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["monthly_timeline"]).to be_an(Array)
    end

    it "returns 404 for non-existent saving" do
      get "/api/v1/savings/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's saving" do
      other_user = create(:user)
      other_saving = create(:saving, user: other_user)

      get "/api/v1/savings/#{other_saving.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/savings/#{saving.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
