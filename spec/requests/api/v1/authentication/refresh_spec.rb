# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication - Refresh", type: :request do
  let(:user) { create(:user, :confirmed) }

  describe "POST /api/v1/refresh" do
    let(:tokens) { Auth::GenerateTokensService.call(user).payload }

    context "with valid refresh token" do
      it "returns new tokens" do
        post "/api/v1/refresh", params: { refresh_token: tokens[:refresh_token] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]).to include("access_token", "refresh_token", "expires_in", "token_type")
        expect(json["data"]["access_token"]).not_to eq(tokens[:access_token])
      end

      it "invalidates old refresh token" do
        old_refresh_token = tokens[:refresh_token]
        post "/api/v1/refresh", params: { refresh_token: old_refresh_token }

        expect(response).to have_http_status(:ok)

        # Try using old refresh token again
        post "/api/v1/refresh", params: { refresh_token: old_refresh_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end

    context "with invalid refresh token" do
      it "returns error with missing token" do
        post "/api/v1/refresh", params: { refresh_token: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_TOKEN_REQUIRED")
        expect(json["error"]["message"]).to eq("Refresh token required")
      end

      it "returns error with invalid token" do
        post "/api/v1/refresh", params: { refresh_token: "invalid_token" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end

      it "returns error with expired token" do
        expired_token = JsonWebToken.encode(
          { user_id: user.id, jti: user.jti, type: "refresh" },
          -1.day
        )

        post "/api/v1/refresh", params: { refresh_token: expired_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end

      it "returns error with access token instead of refresh token" do
        post "/api/v1/refresh", params: { refresh_token: tokens[:access_token] }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end

    context "with revoked token" do
      it "returns error when JTI doesn't match" do
        refresh_token = tokens[:refresh_token]
        user.update!(jti: JsonWebToken.generate_jti)

        post "/api/v1/refresh", params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end
  end
end
