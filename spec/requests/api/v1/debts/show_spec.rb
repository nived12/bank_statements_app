# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Debts - Show", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:debt) { create(:debt, user: user, name: "Credit Card") }

  describe "GET /api/v1/debts/:id" do
    it "returns the debt details" do
      get "/api/v1/debts/#{debt.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(debt.id)
      expect(json["data"]["name"]).to eq("Credit Card")
      expect(json["data"]["progress_percentage"]).to be_present
      expect(json["data"]["amount_remaining"]).to be_present
      expect(json["data"]["amount_paid"]).to be_present
    end

    it "includes monthly timeline data" do
      get "/api/v1/debts/#{debt.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["monthly_timeline"]).to be_an(Array)
    end

    it "returns 404 for non-existent debt" do
      get "/api/v1/debts/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's debt" do
      other_user = create(:user, :confirmed)
      other_debt = create(:debt, user: other_user)

      get "/api/v1/debts/#{other_debt.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/debts/#{debt.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
