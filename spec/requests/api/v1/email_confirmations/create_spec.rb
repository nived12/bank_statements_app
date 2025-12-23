# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EmailConfirmations - Create", type: :request do
  describe "POST /api/v1/email_confirmations" do
    context "with unconfirmed user" do
      let!(:user) { create(:user, email: "user@example.com", confirmed_at: nil) }

      it "returns success message" do
        post "/api/v1/email_confirmations", params: { email: "user@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
      end

      it "sends confirmation email" do
        expect do
          post "/api/v1/email_confirmations", params: { email: "user@example.com" }
        end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "handles case-insensitive email" do
        expect do
          post "/api/v1/email_confirmations", params: { email: "USER@EXAMPLE.COM" }
        end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "handles email with extra whitespace" do
        expect do
          post "/api/v1/email_confirmations", params: { email: "  user@example.com  " }
        end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with already confirmed user" do
      let!(:user) { create(:user, :confirmed, email: "confirmed@example.com") }

      it "returns success message but does not send email" do
        expect do
          post "/api/v1/email_confirmations", params: { email: "confirmed@example.com" }
        end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with non-existent email" do
      it "returns same success message (security)" do
        post "/api/v1/email_confirmations", params: { email: "nonexistent@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_empty
      end

      it "does not send email" do
        expect do
          post "/api/v1/email_confirmations", params: { email: "nonexistent@example.com" }
        end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end
end
