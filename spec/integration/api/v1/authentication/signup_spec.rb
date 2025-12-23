# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Authentication - Signup", type: :request) do
  path "/api/v1/signup" do
    post "Create a new user account" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      description "Register a new user account and receive JWT tokens for authentication"

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email, description: "User's email address", example: "john@example.com" },
              password: { type: :string, format: :password, description: "Password (minimum 6 characters)", example: "password123" },
              first_name: { type: :string, description: "User's first name", example: "John" },
              last_name: { type: :string, description: "User's last name", example: "Doe" }
            },
            required: [:email, :password, :first_name, :last_name]
          }
        },
        required: [:user],
        example: {
          user: {
            email: "john@example.com",
            password: "password123",
            first_name: "John",
            last_name: "Doe"
          }
        }
      }

      response "201", "User created successfully" do
        schema "$ref" => "#/components/schemas/v1_authentication_response"

        let(:user) do
          {
            user: {
              email: "newuser@example.com",
              password: "password123",
              first_name: "John",
              last_name: "Doe"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["access_token"]).to be_present
          expect(data["data"]["refresh_token"]).to be_present
          expect(data["data"]["user"]["email"]).to eq("newuser@example.com")
        end
      end

      response "422", "Validation error" do
        schema "$ref" => "#/components/schemas/validation_error_response"

        let(:user) do
          {
            user: {
              email: "invalid-email",
              password: "123",
              first_name: "",
              last_name: ""
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(data["error"]["details"]).to be_present
        end
      end

      response "422", "Email already taken" do
        schema "$ref" => "#/components/schemas/validation_error_response"

        let!(:existing_user) { create(:user, email: "existing@example.com") }
        let(:user) do
          {
            user: {
              email: "existing@example.com",
              password: "password123",
              first_name: "John",
              last_name: "Doe"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end
    end
  end
end
