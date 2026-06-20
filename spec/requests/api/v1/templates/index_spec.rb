# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Templates - Index", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/templates" do
    it "requires authentication" do
      get "/api/v1/templates"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns savings and debts template catalogs" do
      get "/api/v1/templates", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["savings"].size).to eq(FinancialTemplate::SAVINGS.size)
      expect(json["data"]["debts"].size).to eq(FinancialTemplate::DEBTS.size)
    end

    it "returns the expected fields for a savings template" do
      get "/api/v1/templates", headers: auth_headers.merge("Accept-Language" => "en")

      json = JSON.parse(response.body)
      template = json["data"]["savings"].find { |t| t["key"] == "emergency_fund" }
      expect(template).to include(
        "key" => "emergency_fund",
        "type" => "saving",
        "name" => "Emergency Fund",
        "icon" => "shield"
      )
      expect(template["suggested_target_amount"]).to eq(10_000.0)
      expect(template["calculation_settings"]).to include("income" => "positive")
      expect(template["category_name"]).to eq("Fondo de Emergencia")
    end

    it "localizes names via Accept-Language" do
      get "/api/v1/templates", headers: auth_headers.merge("Accept-Language" => "es")

      json = JSON.parse(response.body)
      template = json["data"]["savings"].find { |t| t["key"] == "emergency_fund" }
      expect(template["name"]).to eq("Fondo de Emergencia")
    end
  end
end
