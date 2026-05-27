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
    it "updates analytics_opt_out" do
      patch "/settings", params: { user_setting: { analytics_opt_out: "1" } }

      expect(response).to redirect_to(settings_path)
      expect(user.user_setting.reload.analytics_opt_out).to eq(true)
    end

    it "toggles analytics_opt_out back off" do
      user.user_setting.update!(preferences: { "analytics_opt_out" => true })
      patch "/settings", params: { user_setting: { analytics_opt_out: "0" } }

      expect(user.user_setting.reload.analytics_opt_out).to eq(false)
    end
  end
end
