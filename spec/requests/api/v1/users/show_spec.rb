# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users - Show", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/user" do
    context "when authenticated" do
      it "returns the current user's profile" do
        get "/api/v1/user", headers: auth_headers

        expect(response).to have_http_status(:success)

        json = JSON.parse(response.body)
        expect(json["data"]["id"]).to eq(user.id)
        expect(json["data"]["email"]).to eq(user.email)
        expect(json["data"]["first_name"]).to eq(user.first_name)
        expect(json["data"]["last_name"]).to eq(user.last_name)
        expect(json["data"]["avatar_url"]).to be_present
      end

      it "includes full_name" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["full_name"]).to eq(user.full_name)
      end

      it "includes confirmed status" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["confirmed"]).to eq(true)
      end

      it "includes subscription_status" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]).to have_key("subscription_status")
        expect(json["data"]["subscription_status"]).to be_a(String)
      end

      it "includes trial_ends_at" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]).to have_key("trial_ends_at")
      end

      it "returns trial_active status for a user within trial period" do
        user.update_column(:trial_ends_at, 10.days.from_now)
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["subscription_status"]).to eq("trial_active")
      end

      it "includes created_at timestamp" do
        get "/api/v1/user", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["created_at"]).to be_present
        expect { DateTime.iso8601(json["data"]["created_at"]) }.not_to raise_error
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/user"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "when token is invalid" do
      it "returns 401 unauthorized" do
        get "/api/v1/user", headers: { "Authorization" => "Bearer invalid.token.here" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end
end
