# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Users - Update", type: :request) do
  path "/api/v1/user" do
    patch "Update current user profile" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      description "Update the authenticated user's profile information (first_name, last_name, avatar_url)"
      security [Bearer: []]

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              first_name: { type: :string, description: "User's first name", example: "Jane" },
              last_name: { type: :string, description: "User's last name", example: "Smith" },
              avatar_url: { type: :string, format: :uri, description: "User's avatar URL", example: "https://example.com/new-avatar.jpg" }
            }
          }
        },
        required: [:user],
        example: {
          user: {
            first_name: "Jane",
            last_name: "Smith",
            avatar_url: "https://example.com/new-avatar.jpg"
          }
        }
      }

      response "200", "User profile updated successfully" do
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                id: { type: :integer },
                email: { type: :string },
                first_name: { type: :string },
                last_name: { type: :string },
                avatar_url: { type: :string },
                created_at: { type: :string },
                updated_at: { type: :string }
              }
            }
          }

        let(:authenticated_user) { create(:user, :consented) }
        let(:access_token) { Auth::GenerateTokensService.call(authenticated_user).payload[:access_token] }
        let(:Authorization) { "Bearer #{access_token}" }
        let(:user) { { user: { first_name: "Jane", last_name: "Smith" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["first_name"]).to eq("Jane")
          expect(data["data"]["last_name"]).to eq("Smith")
        end
      end

      response "422", "Validation error - Invalid user data" do
        schema "$ref" => "#/components/schemas/validation_error_response"

        let(:authenticated_user) { create(:user, :consented) }
        let(:access_token) { Auth::GenerateTokensService.call(authenticated_user).payload[:access_token] }
        let(:Authorization) { "Bearer #{access_token}" }
        let(:user) { { user: { first_name: "", last_name: "" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(data["error"]["details"]).to be_an(Array)
        end
      end

      response "401", "Unauthorized - Invalid or missing access token" do
        schema "$ref" => "#/components/schemas/error_response"

        let(:Authorization) { "Bearer invalid.token" }
        let(:user) { { user: { first_name: "Jane" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end
    end
  end
end
