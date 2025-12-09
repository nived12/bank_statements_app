# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Authentication", type: :request do
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
        schema "$ref" => "#/components/schemas/AuthenticationResponse"

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
        schema "$ref" => "#/components/schemas/ValidationError"

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
        schema "$ref" => "#/components/schemas/ValidationError"

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
              email: { type: :string, format: :email, description: "User's email address", example: "user@example.com" },
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
        schema "$ref" => "#/components/schemas/AuthenticationResponse"

        let!(:existing_user) do
          create(:user, email: "user@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: Time.current)
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
        schema "$ref" => "#/components/schemas/Error"

        let!(:existing_user) do
          create(:user, email: "user@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: Time.current)
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
        schema "$ref" => "#/components/schemas/Error"

        let!(:unconfirmed_user) do
          create(:user, email: "unconfirmed@example.com", password: "password123",
            password_confirmation: "password123", confirmed_at: nil)
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
        schema "$ref" => "#/components/schemas/RefreshResponse"

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
        schema "$ref" => "#/components/schemas/Error"

        let(:token) { { refresh_token: "invalid.token.here" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to be_in(["REFRESH_FAILED", "INVALID_TOKEN"])
        end
      end
    end
  end

  path "/api/v1/logout" do
    delete "Logout and invalidate tokens" do
      tags "Authentication"
      produces "application/json"
      description "Invalidate the current user's refresh token. Access token will remain valid until expiration (15 minutes)."
      security [Bearer: []]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: "Bearer {access_token}"

      response "200", "Logout successful" do
        schema type: :object

        let!(:user) { create(:user) }
        let(:tokens) { Auth::GenerateTokensService.call(user).payload }
        let(:Authorization) { "Bearer #{tokens[:access_token]}" }

        run_test! do |response|
          user.reload
          expect(user.refresh_token_expires_at).to be_nil
        end
      end

      response "401", "Missing or invalid access token" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer invalid.token.here" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to be_in(["INVALID_TOKEN", "UNAUTHORIZED"])
        end
      end

      response "401", "Missing authorization header" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { nil }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("UNAUTHORIZED")
        end
      end
    end
  end
end
