require "rails_helper"

RSpec.describe "PasswordResets", type: :request do
  let(:user) { create(:user, email: "user@example.com", password: "password123", password_confirmation: "password123") }

  before do
    ActionMailer::Base.deliveries.clear
  end

  describe "GET /password_resets/new" do
    it "returns success" do
      get new_password_reset_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /password_resets" do
    context "with valid email" do
      it "enqueues password reset email" do
        expect {
          post password_resets_path, params: { email: user.email }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "redirects to sign in page" do
        post password_resets_path, params: { email: user.email }
        expect(response).to redirect_to(new_session_path)
      end

      it "sets flash notice" do
        post password_resets_path, params: { email: user.email }
        expect(flash[:notice]).to be_present
      end

      it "downcases and strips email before lookup" do
        expect {
          post password_resets_path, params: { email: "  #{user.email.upcase}  " }
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with non-existent email" do
      it "redirects without error to prevent enumeration" do
        post password_resets_path, params: { email: "nonexistent@example.com" }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to be_present
      end

      it "does not enqueue email" do
        expect {
          post password_resets_path, params: { email: "nonexistent@example.com" }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context "with OAuth user" do
      let(:oauth_user) { create(:user, provider: "google_oauth2", uid: "12345", password: "random123", password_confirmation: "random123") }

      it "does not enqueue email for OAuth users" do
        expect {
          post password_resets_path, params: { email: oauth_user.email }
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "redirects without revealing user type" do
        post password_resets_path, params: { email: oauth_user.email }
        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "GET /password_resets/:token/edit" do
    context "with valid token" do
      let(:token) { user.password_reset_token }

      it "returns success" do
        get edit_password_reset_path(token)
        expect(response).to have_http_status(:success)
      end
    end

    context "with invalid token" do
      it "redirects to new password reset path" do
        get edit_password_reset_path("invalid-token")
        expect(response).to redirect_to(new_password_reset_path)
      end

      it "sets alert flash" do
        get edit_password_reset_path("invalid-token")
        expect(flash[:alert]).to be_present
      end
    end

    context "with expired token" do
      it "redirects when token is expired" do
        token = user.password_reset_token

        travel 16.minutes do
          get edit_password_reset_path(token)
          expect(response).to redirect_to(new_password_reset_path)
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe "PATCH /password_resets/:token" do
    let(:token) { user.password_reset_token }
    let(:new_password) { "newpassword123" }

    context "with valid password" do
      it "updates the password" do
        patch password_reset_path(token), params: {
          user: {
            password: new_password,
            password_confirmation: new_password
          }
        }

        user.reload
        expect(user.authenticate(new_password)).to eq(user)
      end

      it "redirects to sign in page" do
        patch password_reset_path(token), params: {
          user: {
            password: new_password,
            password_confirmation: new_password
          }
        }

        expect(response).to redirect_to(new_session_path)
        expect(flash[:notice]).to be_present
      end

      it "invalidates the token after password change" do
        old_token = token

        patch password_reset_path(token), params: {
          user: {
            password: new_password,
            password_confirmation: new_password
          }
        }

        get edit_password_reset_path(old_token)
        expect(response).to redirect_to(new_password_reset_path)
      end
    end

    context "with mismatched passwords" do
      it "renders edit form with unprocessable entity status" do
        patch password_reset_path(token), params: {
          user: {
            password: new_password,
            password_confirmation: "different_password"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not change the password" do
        original_password_digest = user.password_digest

        patch password_reset_path(token), params: {
          user: {
            password: new_password,
            password_confirmation: "different_password"
          }
        }

        user.reload
        expect(user.password_digest).to eq(original_password_digest)
      end
    end

    context "with too short password" do
      it "returns unprocessable entity status" do
        patch password_reset_path(token), params: {
          user: {
            password: "short",
            password_confirmation: "short"
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with invalid token" do
      it "redirects to new password reset path" do
        patch password_reset_path("invalid-token"), params: {
          user: {
            password: new_password,
            password_confirmation: new_password
          }
        }

        expect(response).to redirect_to(new_password_reset_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
