# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication - Logout", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "DELETE /api/v1/logout" do
    let(:tokens) { Auth::GenerateTokensService.call(user).payload }

    context "with valid access token" do
      it "revokes all tokens" do
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{tokens[:access_token]}"
        }

        expect(response).to have_http_status(:ok)
      end

      it "invalidates access token after logout" do
        access_token = tokens[:access_token]

        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{access_token}"
        }

        expect(response).to have_http_status(:ok)

        # Try using the old access token
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{access_token}"
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it "invalidates refresh token after logout" do
        refresh_token = tokens[:refresh_token]

        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{tokens[:access_token]}"
        }

        expect(response).to have_http_status(:ok)

        # Try using the old refresh token
        post "/api/v1/refresh", params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without authentication" do
      it "returns unauthorized error" do
        delete "/api/v1/logout"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "with invalid token" do
      it "returns unauthorized error" do
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer invalid_token"
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end
end
