# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::UserSettings", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/user_settings" do
    context "when authenticated" do
      it "returns default notification preferences" do
        get "/api/v1/user_settings", headers: auth_headers
        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]
        expect(data["notify_statement_imports"]).to be(true)
        expect(data["notify_goal_milestones"]).to be(true)
        expect(data["notify_debt_reminders"]).to be(true)
      end

      it "creates user_settings record if none exists" do
        user.user_setting&.destroy
        expect { get "/api/v1/user_settings", headers: auth_headers }.to change { UserSetting.count }.by(1)
      end

      it "returns existing persisted preferences" do
        user.user_setting.update!(preferences: { "notify_statement_imports" => false })
        get "/api/v1/user_settings", headers: auth_headers
        expect(response.parsed_body["data"]["notify_statement_imports"]).to be(false)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/user_settings"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/user_settings" do
    context "with valid params" do
      it "updates a single preference and returns the updated settings" do
        patch "/api/v1/user_settings",
          params: { settings: { notify_statement_imports: false } },
          headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]["notify_statement_imports"]).to be(false)
        expect(response.parsed_body["data"]["notify_goal_milestones"]).to be(true)
      end

      it "persists the preference to the database" do
        patch "/api/v1/user_settings",
          params: { settings: { notify_goal_milestones: false } },
          headers: auth_headers
        expect(user.user_setting.reload.notify_goal_milestones).to be(false)
      end

      it "allows updating all three preferences at once" do
        patch "/api/v1/user_settings",
          params: { settings: { notify_statement_imports: false, notify_goal_milestones: false,
notify_debt_reminders: false } },
          headers: auth_headers
        data = response.parsed_body["data"]
        expect(data["notify_statement_imports"]).to be(false)
        expect(data["notify_goal_milestones"]).to be(false)
        expect(data["notify_debt_reminders"]).to be(false)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "/api/v1/user_settings", params: { settings: { notify_statement_imports: false } }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "analytics_notice_seen_at" do
      it "is null by default" do
        get "/api/v1/user_settings", headers: auth_headers
        expect(response.parsed_body["data"]["analytics_notice_seen_at"]).to be_nil
      end

      it "stamps an ISO8601 timestamp when set to true" do
        freeze_time = Time.utc(2026, 5, 27, 14, 30, 0)
        travel_to(freeze_time) do
          patch "/api/v1/user_settings",
            params: { settings: { analytics_notice_seen_at: true } },
            headers: auth_headers
        end
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]["analytics_notice_seen_at"]).to eq(freeze_time.iso8601)
        expect(user.user_setting.reload.analytics_notice_seen_at).to eq(freeze_time.iso8601)
      end

      it "clears the stamp when set to false" do
        user.user_setting.update!(preferences: { "analytics_notice_seen_at" => "2026-05-01T00:00:00Z" })
        patch "/api/v1/user_settings",
          params: { settings: { analytics_notice_seen_at: false } },
          headers: auth_headers
        expect(response.parsed_body["data"]["analytics_notice_seen_at"]).to be_nil
      end
    end
  end
end
