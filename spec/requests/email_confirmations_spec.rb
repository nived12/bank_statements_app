require "rails_helper"

RSpec.describe "EmailConfirmations", type: :request do
  describe "GET /email_confirmations/:token" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "with valid token" do
      it "confirms the user's email and redirects to sign in" do
        user.send_confirmation_email
        token = user.reload.confirmation_token

        get email_confirmation_path(token)

        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to eq(I18n.t("email_confirmations.show.success"))

        user.reload
        expect(user.confirmed?).to be true
        expect(user.confirmation_token).to be_nil
      end
    end

    context "with invalid token" do
      it "redirects to sign in with error message" do
        get email_confirmation_path("invalid_token")

        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq(I18n.t("email_confirmations.show.invalid_or_expired"))
      end
    end

    context "with expired token" do
      it "redirects to sign in with error message" do
        user.send_confirmation_email
        token = user.reload.confirmation_token

        # Travel to 25 hours in the future (past the 24 hour expiration)
        travel 25.hours do
          get email_confirmation_path(token)

          expect(response).to redirect_to(new_session_path)
          expect(flash[:alert]).to eq(I18n.t("email_confirmations.show.invalid_or_expired"))
        end
      end
    end
  end
end
