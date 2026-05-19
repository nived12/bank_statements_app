# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Assistant::Usage", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
  end

  describe "GET /api/v1/assistant/usage" do
    it "returns 401 when unauthenticated" do
      get "/api/v1/assistant/usage"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns trial snapshot for trial users" do
      user.update_columns(trial_ends_at: 7.days.from_now, ai_usage_count: 4)

      get "/api/v1/assistant/usage", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["plan"]).to eq("trial")
      expect(data["limit"]).to eq(15)
      expect(data["used"]).to eq(4)
      expect(data["remaining"]).to eq(11)
    end

    it "returns premium snapshot for paid users" do
      user.update_columns(trial_ends_at: nil)
      customer = create(:pay_customer, owner: user)
      create(:pay_subscription, customer: customer, status: "active")
      user.update_columns(assistant_messages_this_month: 12)

      get "/api/v1/assistant/usage", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["plan"]).to eq("premium")
      expect(data["limit"]).to eq(100)
      expect(data["used"]).to eq(12)
      expect(data["remaining"]).to eq(88)
      expect(data["resets_at"]).to be_present
    end

    it "is reachable even when over limit (no gating on usage endpoint)" do
      user.update_columns(trial_ends_at: 7.days.from_now, ai_usage_count: 999)

      get "/api/v1/assistant/usage", headers: auth_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
