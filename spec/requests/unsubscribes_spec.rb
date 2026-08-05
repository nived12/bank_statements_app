require "rails_helper"

RSpec.describe "Unsubscribes", type: :request do
  let(:user) { create(:user, email: "ana@example.com") }
  let(:token) { user.generate_token_for(:email_unsubscribe) }

  describe "GET /unsubscribe/:token" do
    it "renders the confirmation page without a session" do
      get unsubscribe_path(token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.email)
    end

    it "does not opt the user out on its own" do
      # Mail clients and security scanners prefetch GET links; a GET that
      # unsubscribed would fire without the recipient ever choosing it.
      get unsubscribe_path(token: token)

      expect(user.user_setting.reload.notify_trial_reminders).to be true
    end

    it "returns 404 for a garbage token" do
      get unsubscribe_path(token: "not-a-real-token")

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 once the account is discarded" do
      user.discard

      get unsubscribe_path(token: token)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /unsubscribe/:token" do
    it "opts the user out" do
      post unsubscribe_path(token: token)

      expect(response).to have_http_status(:ok)
      expect(user.user_setting.reload.notify_trial_reminders).to be false
    end

    it "accepts a one-click POST with no CSRF token" do
      # RFC 8058: Gmail POSTs here directly from its own unsubscribe button and
      # has no way to carry a Rails authenticity token.
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true

      post unsubscribe_path(token: token)

      expect(response).to have_http_status(:ok)
      expect(user.user_setting.reload.notify_trial_reminders).to be false
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "opts out even when the user has no settings row" do
      user.user_setting.destroy
      user.reload

      post unsubscribe_path(token: token)

      expect(response).to have_http_status(:ok)
      expect(user.reload.user_setting.notify_trial_reminders).to be false
    end

    it "is idempotent" do
      2.times { post unsubscribe_path(token: token) }

      expect(response).to have_http_status(:ok)
      expect(user.user_setting.reload.notify_trial_reminders).to be false
    end

    it "leaves the token valid forever so a late click still works" do
      travel_to 3.years.from_now do
        post unsubscribe_path(token: token)

        expect(response).to have_http_status(:ok)
        expect(user.user_setting.reload.notify_trial_reminders).to be false
      end
    end

    it "returns 404 for a garbage token" do
      post unsubscribe_path(token: "not-a-real-token")

      expect(response).to have_http_status(:not_found)
    end
  end
end
