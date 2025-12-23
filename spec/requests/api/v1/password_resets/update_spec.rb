# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PasswordResets - Update", type: :request do
  describe "PATCH /api/v1/password_resets/:token" do
    let(:user) { create(:user, email: "user@example.com") }
    let(:token) { user.generate_token_for(:password_reset) }

    context "with valid token and password" do
      let(:valid_params) do
        {
          user: {
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }
      end

      it "resets the password" do
        patch "/api/v1/password_resets/#{token}", params: valid_params

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty

        user.reload
        expect(user.authenticate("newpassword123")).to be_truthy
      end

      it "allows login with new password for confirmed users" do
        user.update(confirmed_at: Time.current)
        patch "/api/v1/password_resets/#{token}", params: valid_params

        post "/api/v1/login", params: {
          user: {
            email: "user@example.com",
            password: "newpassword123"
          }
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["access_token"]).to be_present
      end
    end

    context "with invalid token" do
      it "returns error" do
        patch "/api/v1/password_resets/invalid-token", params: {
          user: {
            password: "newpassword123",
            password_confirmation: "newpassword123"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_TOKEN")
        expect(json["error"]["message"]).to include("invalid or has expired")
      end
    end


    context "with invalid password" do
      it "returns validation errors for short password" do
        patch "/api/v1/password_resets/#{token}", params: {
          user: {
            password: "short",
            password_confirmation: "short"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"]).to be_an(Array)
        expect(json["error"]["details"].first["field"]).to eq("password")
      end

      it "returns validation errors for password mismatch" do
        patch "/api/v1/password_resets/#{token}", params: {
          user: {
            password: "password123",
            password_confirmation: "different123"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "with missing parameters" do
      it "returns error when password is missing" do
        patch "/api/v1/password_resets/#{token}", params: { user: {} }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
