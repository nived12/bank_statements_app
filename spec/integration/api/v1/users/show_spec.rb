# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Users - Show", type: :request) do
  path "/api/v1/user" do
    get "Get current user profile" do
      tags "Users"
      produces "application/json"
      description "Returns the authenticated user's profile information"
      security [Bearer: []]

      response "200", "User profile retrieved successfully" do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :integer, description: "User ID", example: 1 },
                email: { type: :string, format: :email, description: "User's email address",
example: "user@example.com" },
                first_name: { type: :string, description: "User's first name", example: "John" },
                last_name: { type: :string, description: "User's last name", example: "Doe" },
                avatar_url: { type: :string, format: :uri, description: "User's avatar URL",
example: "https://example.com/avatar.jpg" },
                created_at: { type: :string, format: "date-time", description: "Account creation date (ISO 8601)",
example: "2024-01-15T10:30:00Z" },
                updated_at: { type: :string, format: "date-time", description: "Account update date (ISO 8601)",
example: "2024-01-15T10:30:00Z" }
              },
              required: [:id, :email, :first_name, :last_name, :avatar_url, :created_at, :updated_at]
            }
          },
          required: [:data]

        let(:user) { create(:user, :confirmed) }
        let(:access_token) { Auth::GenerateTokensService.call(user).payload[:access_token] }
        let(:Authorization) { "Bearer #{access_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["id"]).to eq(user.id)
          expect(data["data"]["email"]).to eq(user.email)
        end
      end

      response "401", "Unauthorized - Invalid or missing access token" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:Authorization) { "Bearer invalid.token" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end
    end
  end
end
