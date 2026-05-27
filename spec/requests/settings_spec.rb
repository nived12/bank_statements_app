require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
    allow_any_instance_of(ApplicationController)
      .to receive(:handle_internal_server_error)
      .and_wrap_original { |_m, exc| raise exc }
  end

  describe "GET /settings" do
    it "renders with all three sections" do
      get "/settings"

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("settings.sections.preferences"))
      expect(response.body).to include(I18n.t("settings.sections.help"))
      expect(response.body).to include(I18n.t("settings.sections.account"))
    end
  end

  describe "PATCH /settings" do
    it "disables analytics_enabled when unchecked" do
      patch "/settings", params: { user_setting: { analytics_enabled: "0" } }

      expect(response).to redirect_to(settings_path)
      expect(user.user_setting.reload.analytics_enabled).to eq(false)
    end

    it "re-enables analytics_enabled when checked" do
      user.user_setting.update!(preferences: { "analytics_enabled" => false })
      patch "/settings", params: { user_setting: { analytics_enabled: "1" } }

      expect(user.user_setting.reload.analytics_enabled).to eq(true)
    end
  end
end
