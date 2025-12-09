# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication", type: :request do
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

  describe "POST /api/v1/signup" do
    let(:valid_signup_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "John",
          last_name: "Doe"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new user and returns tokens" do
        expect {
          post "/api/v1/signup", params: valid_signup_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json["data"]).to include("access_token", "refresh_token", "expires_in", "token_type")
        expect(json["data"]["user"]["email"]).to eq("newuser@example.com")
        expect(json["data"]["user"]["first_name"]).to eq("John")
        expect(json["data"]["user"]["last_name"]).to eq("Doe")
      end

      it "stores email in lowercase" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].merge(email: "NewUser@EXAMPLE.com")
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["user"]["email"]).to eq("newuser@example.com")
      end

      it "sends confirmation email for non-OAuth users" do
        expect {
          post "/api/v1/signup", params: valid_signup_params
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with invalid parameters" do
      it "returns validation errors for missing email" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].except(:email)
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"]).to be_an(Array)
        expect(json["error"]["details"].any? { |d| d["field"] == "email" }).to be true
      end

      it "returns validation error for password mismatch" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].merge(password_confirmation: "different")
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"].any? { |d| d["field"] == "password_confirmation" }).to be true
      end

      it "returns validation error for duplicate email" do
        create(:user, email: "newuser@example.com")

        post "/api/v1/signup", params: valid_signup_params

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"].any? { |d| d["field"] == "email" }).to be true
      end

      it "returns validation error for short password" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].merge(password: "short", password_confirmation: "short")
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end
  end

  describe "POST /api/v1/refresh" do
    let(:tokens) { Auth::GenerateTokensService.call(user).payload }

    context "with valid refresh token" do
      it "returns new tokens" do
        post "/api/v1/refresh", params: { refresh_token: tokens[:refresh_token] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json["data"]).to include("access_token", "refresh_token", "expires_in", "token_type")
        expect(json["data"]["access_token"]).not_to eq(tokens[:access_token])
      end

      it "invalidates old refresh token" do
        old_refresh_token = tokens[:refresh_token]
        post "/api/v1/refresh", params: { refresh_token: old_refresh_token }

        expect(response).to have_http_status(:ok)

        # Try using old refresh token again
        post "/api/v1/refresh", params: { refresh_token: old_refresh_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end

    context "with invalid refresh token" do
      it "returns error with missing token" do
        post "/api/v1/refresh", params: { refresh_token: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_TOKEN_REQUIRED")
        expect(json["error"]["message"]).to eq("Refresh token required")
      end

      it "returns error with invalid token" do
        post "/api/v1/refresh", params: { refresh_token: "invalid_token" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end

      it "returns error with expired token" do
        expired_token = JsonWebToken.encode(
          { user_id: user.id, jti: user.jti, type: "refresh" },
          -1.day
        )

        post "/api/v1/refresh", params: { refresh_token: expired_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end

      it "returns error with access token instead of refresh token" do
        post "/api/v1/refresh", params: { refresh_token: tokens[:access_token] }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end

    context "with revoked token" do
      it "returns error when JTI doesn't match" do
        refresh_token = tokens[:refresh_token]
        user.update!(jti: JsonWebToken.generate_jti)

        post "/api/v1/refresh", params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("REFRESH_FAILED")
      end
    end
  end

  describe "DELETE /api/v1/logout" do
    let(:tokens) { Auth::GenerateTokensService.call(user).payload }

    context "with valid access token" do
      it "revokes all tokens" do
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{tokens[:access_token]}"
        }

        expect(response).to have_http_status(:ok)
      end

      it "invalidates access token after logout" do
        access_token = tokens[:access_token]

        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{access_token}"
        }

        expect(response).to have_http_status(:ok)

        # Try using the old access token
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{access_token}"
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it "invalidates refresh token after logout" do
        refresh_token = tokens[:refresh_token]

        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer #{tokens[:access_token]}"
        }

        expect(response).to have_http_status(:ok)

        # Try using the old refresh token
        post "/api/v1/refresh", params: { refresh_token: refresh_token }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without authentication" do
      it "returns unauthorized error" do
        delete "/api/v1/logout"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "with invalid token" do
      it "returns unauthorized error" do
        delete "/api/v1/logout", headers: {
          "Authorization" => "Bearer invalid_token"
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end
end
