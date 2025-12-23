# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Authentication - Refresh", type: :request) do
  path "/api/v1/refresh" do
    post "Refresh access token" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      description "Use a valid refresh token to obtain a new access token and refresh token pair"

      parameter name: :token, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string, description: "Valid JWT refresh token", example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
        },
        required: [:refresh_token],
        example: {
          refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        }
      }

      response "200", "Token refreshed successfully" do
        schema "$ref" => "#/components/schemas/v1_refresh_response"

        let!(:user) { create(:user) }
        let(:refresh_token) do
          Auth::GenerateTokensService.call(user).payload[:refresh_token]
        end
        let(:token) { { refresh_token: refresh_token } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["access_token"]).to be_present
          expect(data["data"]["refresh_token"]).to be_present
        end
      end

      response "401", "Invalid or expired refresh token" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:token) { { refresh_token: "invalid.token.here" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("REFRESH_FAILED")
        end
      end
    end
  end
end
