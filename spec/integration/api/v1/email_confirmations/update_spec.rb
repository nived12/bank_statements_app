# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Email Confirmations - Update", type: :request) do
  path "/api/v1/email_confirmations/{token}" do
    patch "Confirm email with token" do
      tags "Email Confirmation"
      consumes "application/json"
      produces "application/json"
      description "Confirm user email using the token from the confirmation email. Returns JWT tokens upon successful confirmation for immediate API access."

      parameter name: :token, in: :path, type: :string, description: "Email confirmation token from email"

      response "200", "Email confirmed successfully (with auto-login)" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string, example: "Email confirmed successfully" },
                     confirmed: { type: :boolean, example: true },
                     access_token: { type: :string, description: "JWT access token for API requests", example: "eyJhbGciOiJIUzI1NiJ9..." },
                     refresh_token: { type: :string, description: "JWT refresh token for obtaining new access tokens", example: "eyJhbGciOiJIUzI1NiJ9..." },
                     expires_in: { type: :integer, description: "Access token expiration time in seconds", example: 900 },
                     token_type: { type: :string, example: "Bearer" },
                     user: { "$ref" => "#/components/schemas/v1_user_response" }
                   },
                   required: [:message, :confirmed]
                 }
               }

        let!(:user) { create(:user, email: "user@example.com", confirmed_at: nil) }
        let(:token) { user.generate_token_for(:email_confirmation) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["message"]).to include("confirmed successfully")
          expect(data["data"]["confirmed"]).to be true
          expect(data["data"]["access_token"]).to be_present
          expect(data["data"]["refresh_token"]).to be_present
          expect(data["data"]["user"]).to be_present
        end
      end

      response "200", "Email already confirmed (no tokens returned)" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string, example: "Email is already confirmed" },
                     confirmed: { type: :boolean, example: true }
                   }
                 }
               }

        let!(:user) { create(:user, :confirmed, email: "confirmed@example.com") }
        let(:token) { user.generate_token_for(:email_confirmation) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["message"]).to include("already confirmed")
          expect(data["data"]["confirmed"]).to be true
          expect(data["data"]["access_token"]).to be_nil
        end
      end

      response "422", "Invalid or expired token" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:token) { "invalid-token" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("INVALID_TOKEN")
          expect(data["error"]["message"]).to include("invalid or has expired")
        end
      end
    end
  end
end
