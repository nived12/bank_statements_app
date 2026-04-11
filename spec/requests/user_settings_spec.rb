# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserSettings", type: :request do
  let(:user) { create(:user) }

  before { sign_in_user(user) }

  describe "PATCH /user_settings" do
    context "with a valid theme value" do
      it "updates the theme preference and returns ok" do
        patch user_settings_path, params: { theme: "dark" }
        expect(response).to have_http_status(:ok)
        expect(user.user_settings.reload.theme).to eq("dark")
      end

      it "accepts light theme" do
        patch user_settings_path, params: { theme: "light" }
        expect(response).to have_http_status(:ok)
        expect(user.user_settings.reload.theme).to eq("light")
      end

      it "accepts system theme" do
        patch user_settings_path, params: { theme: "system" }
        expect(response).to have_http_status(:ok)
        expect(user.user_settings.reload.theme).to eq("system")
      end
    end

    context "without a theme param" do
      it "returns ok without changing theme" do
        original_theme = user.user_settings.theme
        patch user_settings_path, params: {}
        expect(response).to have_http_status(:ok)
        expect(user.user_settings.reload.theme).to eq(original_theme)
      end
    end

    context "when unauthenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it "redirects to sign in" do
        patch user_settings_path, params: { theme: "dark" }
        expect(response).to redirect_to(new_session_path)
      end
    end
  end
end
