# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Categories - Show", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/categories/:id" do
    let(:category) { create(:category, user: user, name: "Food") }
    let!(:subcategory) { create(:category, user: user, name: "Groceries", parent: category) }

    it "returns category details with subcategories" do
      get "/api/v1/categories/#{category.id}", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["id"]).to eq(category.id)
      expect(json["data"]["name"]).to eq("Food")
      expect(json["data"]["children"].length).to eq(1)
      expect(json["data"]["children"].first["name"]).to eq("Groceries")
    end

    it "returns 404 for non-existent category" do
      get "/api/v1/categories/999999", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:not_found)
      expect(json["error"]["code"]).to eq("CATEGORY_NOT_FOUND")
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/categories/#{category.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
