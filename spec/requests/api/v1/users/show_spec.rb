# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Users - Show", type: :request do
  let(:user) { create(:user, :confirmed) }
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
