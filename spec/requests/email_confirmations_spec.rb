require "rails_helper"

RSpec.describe "EmailConfirmations", type: :request do
  describe "GET /email_confirmations/:token" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "with valid token" do
      it "confirms the user's email and redirects to sign in" do
        token = user.generate_token_for(:email_confirmation)

        get email_confirmation_path(token)

        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to eq(I18n.t("email_confirmations.show.success"))

        user.reload
        expect(user.confirmed?).to be true
      end
    end

    context "with already confirmed user" do
      it "shows already confirmed message" do
        user.update!(confirmed_at: Time.current)
        token = user.generate_token_for(:email_confirmation)

        get email_confirmation_path(token)

        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to eq(I18n.t("email_confirmations.show.already_confirmed"))
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
        token = user.generate_token_for(:email_confirmation)

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
