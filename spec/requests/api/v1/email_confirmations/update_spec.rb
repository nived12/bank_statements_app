# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EmailConfirmations - Update", type: :request do
  describe "PATCH /api/v1/email_confirmations/:token" do
    let(:user) { create(:user, email: "user@example.com", confirmed_at: nil) }
    let(:token) { user.generate_token_for(:email_confirmation) }

    context "with valid token" do
      it "confirms the email" do
        patch "/api/v1/email_confirmations/#{token}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["message"]).to include("confirmed successfully")

        user.reload
        expect(user.confirmed?).to be true
      end

      it "returns JWT tokens after confirmation" do
        patch "/api/v1/email_confirmations/#{token}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["access_token"]).to be_present
        expect(json["data"]["refresh_token"]).to be_present
        expect(json["data"]["token_type"]).to eq("Bearer")
        expect(json["data"]["user"]).to be_present
        expect(json["data"]["user"]["email"]).to eq("user@example.com")
        expect(json["data"]["user"]["confirmed"]).to be true
      end

      it "allows immediate API access with returned token" do
        patch "/api/v1/email_confirmations/#{token}"

        json = JSON.parse(response.body)
        access_token = json["data"]["access_token"]

        get "/api/v1/user", headers: { "Authorization" => "Bearer #{access_token}" }

        expect(response).to have_http_status(:ok)
      end
    end

    context "with already confirmed email" do
      let!(:confirmed_user) { create(:user, :confirmed, email: "confirmed@example.com") }
      let(:confirmed_token) { confirmed_user.generate_token_for(:email_confirmation) }

      it "returns success with already confirmed message" do
        patch "/api/v1/email_confirmations/#{confirmed_token}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["message"]).to include("already confirmed")
        expect(json["data"]["confirmed"]).to be true
      end

      it "does not return tokens for already confirmed" do
        patch "/api/v1/email_confirmations/#{confirmed_token}"

        json = JSON.parse(response.body)
        expect(json["data"]["access_token"]).to be_nil
      end
    end

    context "with invalid token" do
      it "returns error" do
        patch "/api/v1/email_confirmations/invalid-token"

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_TOKEN")
        expect(json["error"]["message"]).to include("invalid or has expired")
      end
    end
  end
end
