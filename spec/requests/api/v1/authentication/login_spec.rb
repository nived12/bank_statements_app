# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication - Login", type: :request do
  let(:user) { create(:user, :confirmed, password: "password123", password_confirmation: "password123") }

  describe "POST /api/v1/login" do
    context "with valid credentials" do
      it "returns tokens and user data" do
        post "/api/v1/login", params: {
          user: { email: user.email, password: "password123" }
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]).to include("access_token", "refresh_token", "expires_in", "token_type")
        expect(json["data"]["token_type"]).to eq("Bearer")
        expect(json["data"]["user"]["id"]).to eq(user.id)
        expect(json["data"]["user"]["email"]).to eq(user.email)
      end

      it "returns confirmed status for user" do
        post "/api/v1/login", params: {
          user: { email: user.email, password: "password123" }
        }

        json = JSON.parse(response.body)
        expect(json["data"]["user"]["confirmed"]).to be true
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized error with wrong password" do
        post "/api/v1/login", params: {
          user: { email: user.email, password: "wrongpassword" }
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_CREDENTIALS")
        expect(json["error"]["message"]).to eq("Invalid email or password")
      end

      it "returns unauthorized error with non-existent email" do
        post "/api/v1/login", params: {
          user: { email: "nonexistent@example.com", password: "password123" }
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_CREDENTIALS")
      end
    end

    context "with unconfirmed email" do
      let(:unconfirmed_user) { create(:user, password: "password123", password_confirmation: "password123") }

      it "returns forbidden error" do
        post "/api/v1/login", params: {
          user: { email: unconfirmed_user.email, password: "password123" }
        }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("EMAIL_NOT_CONFIRMED")
        expect(json["error"]["message"]).to eq("Please confirm your email address before logging in")
      end
    end

    context "with case-insensitive email" do
      it "logs in with uppercase email" do
        post "/api/v1/login", params: {
          user: { email: user.email.upcase, password: "password123" }
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["user"]["email"]).to eq(user.email)
      end
    end
  end
end
