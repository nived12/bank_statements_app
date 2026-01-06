# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Authentication - Login", type: :request) do
  path "/api/v1/login" do
    post "Authenticate user and get tokens" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      description "Login with email and password to receive JWT access and refresh tokens"

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: { type: :string, format: :email, description: "User's email address",
example: "user@example.com" },
              password: { type: :string, format: :password, description: "User's password", example: "password123" }
            },
            required: [:email, :password]
          }
        },
        required: [:user],
        example: {
          user: {
            email: "user@example.com",
            password: "password123"
          }
        }
      }

      response "200", "Login successful" do
        schema "$ref" => "#/components/schemas/v1_authentication_response"

        let!(:existing_user) do
          create(
            :user, email: "user@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: Time.current
          )
        end
        let(:credentials) do
          {
            user: {
              email: "user@example.com",
              password: "password123"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["access_token"]).to be_present
          expect(data["data"]["refresh_token"]).to be_present
          expect(data["data"]["user"]["email"]).to eq("user@example.com")
        end
      end

      response "401", "Invalid credentials" do
        schema "$ref" => "#/components/schemas/error_response"

        let!(:existing_user) do
          create(
            :user, email: "user@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: Time.current
          )
        end
        let(:credentials) do
          {
            user: {
              email: "user@example.com",
              password: "wrongpassword"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("INVALID_CREDENTIALS")
        end
      end

      response "403", "Email not confirmed" do
        schema "$ref" => "#/components/schemas/error_response"

        let!(:unconfirmed_user) do
          create(
            :user, email: "unconfirmed@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: nil
          )
        end
        let(:credentials) do
          {
            user: {
              email: "unconfirmed@example.com",
              password: "password123"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("EMAIL_NOT_CONFIRMED")
        end
      end
    end
  end
end
