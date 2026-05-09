# frozen_string_literal: true

require "rails_helper"

# Tests for ApiAuthenticatable concern — covering all JWT bypass paths.
# Uses GET /api/v1/dashboard as a representative authenticated endpoint.
RSpec.describe "Api::V1 JWT middleware (ApiAuthenticatable)", type: :request do
  let(:user) { create(:user) }

  describe "authentication guard" do
    context "with missing Authorization header" do
      it "returns 401" do
        get "/api/v1/dashboard"

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
        expect(json["error"]["message"]).to match(/missing/i)
      end
    end

    context "with malformed Authorization header (no Bearer prefix)" do
      it "returns 401" do
        get "/api/v1/dashboard", headers: { "Authorization" => JsonWebToken.generate_access_token(user) }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "with invalid signature" do
      it "returns 401" do
        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer invalid.token.signature" }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "with an expired access token" do
      it "returns 401" do
        expired_token = JsonWebToken.encode(
          { user_id: user.id, jti: user.jti, type: "access" },
          -1.minute
        )

        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer #{expired_token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "with a refresh token used as an access token" do
      it "returns 401 (wrong token type)" do
        refresh_token = JsonWebToken.generate_refresh_token(user)

        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer #{refresh_token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
        expect(json["error"]["message"]).to match(/invalid token type/i)
      end
    end

    context "with a revoked token (JTI mismatch)" do
      it "returns 401" do
        valid_token = JsonWebToken.generate_access_token(user)

        # Rotate the user's JTI — simulates logout/revocation
        user.update!(jti: JsonWebToken.generate_jti)

        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer #{valid_token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
        expect(json["error"]["message"]).to match(/revoked/i)
      end
    end

    context "with a valid access token" do
      it "allows the request through" do
        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer #{JsonWebToken.generate_access_token(user)}" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  private

  def json
    JSON.parse(response.body)
  end
end
