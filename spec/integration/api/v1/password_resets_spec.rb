# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Password Resets", type: :request do
  path "/api/v1/password_resets" do
    post "Request password reset" do
      tags "Password Reset"
      consumes "application/json"
      produces "application/json"
      description "Request a password reset email. Returns success message regardless of whether email exists (security measure to prevent email enumeration)."

      parameter name: :email_params, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, description: "Email address to send password reset instructions", example: "user@example.com" }
        },
        required: [:email],
        example: {
          email: "user@example.com"
        }
      }

      response "200", "Password reset email sent (if email exists)" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string, example: "If your email exists in our system, you will receive password reset instructions" }
                   }
                 }
               }

        let!(:user) { create(:user, :confirmed, email: "user@example.com") }
        let(:email_params) { { email: "user@example.com" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["message"]).to include("password reset instructions")
        end
      end
    end
  end

  path "/api/v1/password_resets/{token}" do
    patch "Reset password with token" do
      tags "Password Reset"
      consumes "application/json"
      produces "application/json"
      description "Reset user password using the token from the password reset email"

      parameter name: :token, in: :path, type: :string, description: "Password reset token from email"

      parameter name: :password_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              password: { type: :string, format: :password, description: "New password (minimum 6 characters)", example: "newpassword123" },
              password_confirmation: { type: :string, format: :password, description: "Password confirmation (must match password)", example: "newpassword123" }
            },
            required: [:password, :password_confirmation]
          }
        },
        required: [:user],
        example: {
          user: {
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      }

      response "200", "Password reset successful" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     message: { type: :string, example: "Password has been reset successfully" }
                   }
                 }
               }

        let!(:user) { create(:user, :confirmed, email: "user@example.com") }
        let(:token) { user.generate_token_for(:password_reset) }
        let(:password_params) do
          {
            user: {
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["message"]).to include("reset successfully")
        end
      end

      response "422", "Invalid or expired token" do
        schema "$ref" => "#/components/schemas/Error"

        let(:token) { "invalid-token" }
        let(:password_params) do
          {
            user: {
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("INVALID_TOKEN")
          expect(data["error"]["message"]).to include("invalid or has expired")
        end
      end

      response "422", "Validation error (password too short)" do
        schema "$ref" => "#/components/schemas/ValidationError"

        let!(:user) { create(:user, :confirmed, email: "user@example.com") }
        let(:token) { user.generate_token_for(:password_reset) }
        let(:password_params) do
          {
            user: {
              password: "short",
              password_confirmation: "short"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(data["error"]["details"]).to be_present
        end
      end

      response "422", "Validation error (password mismatch)" do
        schema "$ref" => "#/components/schemas/ValidationError"

        let!(:user) { create(:user, :confirmed, email: "user@example.com") }
        let(:token) { user.generate_token_for(:password_reset) }
        let(:password_params) do
          {
            user: {
              password: "password123",
              password_confirmation: "different123"
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
