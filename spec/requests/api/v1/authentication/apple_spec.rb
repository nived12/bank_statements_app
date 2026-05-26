# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication - Apple", type: :request do
  let(:apple_user) { create(:user, provider: "apple", uid: "apple-sub-123") }

  describe "POST /api/v1/auth/apple" do
    context "when the authenticator succeeds" do
      it "returns Vittio JWT tokens and user payload" do
        allow(Auth::AppleAuthenticator).to receive(:call).and_return(
          ApplicationService::Response.new(success: true, payload: apple_user, errors: nil)
        )

        post "/api/v1/auth/apple", params: { identity_token: "fake-apple-token" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]).to include("access_token", "refresh_token", "expires_in", "token_type")
        expect(json["data"]["user"]["id"]).to eq(apple_user.id)
      end
    end

    context "when the authenticator fails" do
      it "returns 401 with APPLE_AUTH_FAILED" do
        errors = ActiveModel::Errors.new(Object.new)
        errors.add(:base, "Invalid Apple identity token")
        allow(Auth::AppleAuthenticator).to receive(:call).and_return(
          ApplicationService::Response.new(success: false, payload: nil, errors: errors)
        )

        post "/api/v1/auth/apple", params: { identity_token: "bad-token" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("APPLE_AUTH_FAILED")
      end
    end
  end
end
