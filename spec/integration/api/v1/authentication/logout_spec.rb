# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Authentication - Logout", type: :request) do
  path "/api/v1/logout" do
    delete "Logout and invalidate tokens" do
      tags "Authentication"
      produces "application/json"
      description "Invalidate the current user's refresh token. Access token will remain valid until expiration (15 minutes)."
      security [Bearer: []]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer {access_token}"

      response "200", "Logout successful" do
        let!(:user) { create(:user) }
        let(:tokens) { Auth::GenerateTokensService.call(user).payload }
        let(:Authorization) { "Bearer #{tokens[:access_token]}" }

        run_test! do |response|
          expect(response.body).to be_empty
          user.reload
          expect(user.refresh_token_expires_at).to be_nil
        end
      end

      response "401", "Missing or invalid access token" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:Authorization) { "Bearer invalid.token.here" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end

      response "401", "Missing authorization header" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:Authorization) { nil }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end
    end
  end
end
