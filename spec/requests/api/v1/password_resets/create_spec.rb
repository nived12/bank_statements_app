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
