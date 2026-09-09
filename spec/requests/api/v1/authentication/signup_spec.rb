# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Authentication - Signup", type: :request do
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

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"]).to be_an(Array)
        expect(json["error"]["details"].any? { |d| d["field"] == "email" }).to be true
      end

      it "returns validation error for password mismatch" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].merge(password_confirmation: "different")
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"].any? { |d| d["field"] == "password_confirmation" }).to be true
      end

      it "returns validation error for duplicate email" do
        create(:user, email: "newuser@example.com")

        post "/api/v1/signup", params: valid_signup_params

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"].any? { |d| d["field"] == "email" }).to be true
      end

      it "returns validation error for short password" do
        post "/api/v1/signup", params: {
          user: valid_signup_params[:user].merge(password: "short", password_confirmation: "short")
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end
  end
end
