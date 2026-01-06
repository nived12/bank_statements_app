# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Password Resets - Update", type: :request) do
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
              password: { type: :string, format: :password, description: "New password (minimum 6 characters)",
example: "newpassword123" },
              password_confirmation: { type: :string, format: :password,
description: "Password confirmation (must match password)", example: "newpassword123" }
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
          expect(response.body).to be_empty
        end
      end

      response "422", "Invalid or expired token" do
        schema "$ref" => "#/components/schemas/error_response"

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
        schema "$ref" => "#/components/schemas/validation_error_response"

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
        schema "$ref" => "#/components/schemas/validation_error_response"

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
