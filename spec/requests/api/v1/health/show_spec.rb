# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Health - Show", type: :request do
  describe "GET /api/v1/health" do
    it "returns 200 with the envelope" do
      get "/api/v1/health"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json).to have_key("data")
      expect(json["data"]["status"]).to eq("ok")
      expect(json["data"]["version"]).to eq(Api::V1::HealthController::VERSION)
      expect(json["data"]["time"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "does not require authentication" do
      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
    end

    it "does not require legal consent" do
      get "/api/v1/health", headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["status"]).to eq("ok")
    end
  end
end
