# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::PasswordResets - Create", type: :request do
  describe "POST /api/v1/password_resets" do
    context "with valid email" do
      let!(:user) { create(:user, email: "user@example.com") }

      it "returns success message" do
        post "/api/v1/password_resets", params: { email: "user@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
      end

      it "sends password reset email" do
        expect {
          post "/api/v1/password_resets", params: { email: "user@example.com" }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "handles case-insensitive email" do
        expect {
          post "/api/v1/password_resets", params: { email: "USER@EXAMPLE.COM" }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "handles email with extra whitespace" do
        expect {
          post "/api/v1/password_resets", params: { email: "  user@example.com  " }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with an OAuth-only account" do
      let!(:oauth_user) { create(:user, :oauth, email: "google@example.com", password: "password123") }

      it "returns OAUTH_ACCOUNT error" do
        post "/api/v1/password_resets", params: { user: { email: "google@example.com" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("error", "code")).to eq("OAUTH_ACCOUNT")
      end

      it "does not send a password reset email" do
        expect {
          post "/api/v1/password_resets", params: { user: { email: "google@example.com" } }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with non-existent email" do
      it "returns same success message (security)" do
        post "/api/v1/password_resets", params: { email: "nonexistent@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
      end

      it "does not send email" do
        expect {
          post "/api/v1/password_resets", params: { email: "nonexistent@example.com" }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end
end
