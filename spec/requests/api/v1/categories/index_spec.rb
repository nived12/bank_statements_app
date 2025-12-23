# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Categories - Index", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "GET /api/v1/categories" do
    let!(:parent_category1) { create(:category, user: user, name: "Food") }
    let!(:parent_category2) { create(:category, user: user, name: "Transport") }
    let!(:subcategory1) { create(:category, user: user, name: "Groceries", parent: parent_category1) }
    let!(:subcategory2) { create(:category, user: user, name: "Restaurants", parent: parent_category1) }

    it "returns hierarchical categories list" do
      get "/api/v1/categories", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      # User has default categories (25 parent categories) plus custom ones
      expect(json["data"]["categories"].length).to be >= 2

      food_category = json["data"]["categories"].find { |c| c["name"] == "Food" }
      expect(food_category["children"].length).to eq(2)
      expect(food_category["children"].map { |c| c["name"] }).to match_array(["Groceries", "Restaurants"])
    end

    it "includes transactions count for categories" do
      bank = create(:bank, name: "Test Bank")
      bank_account = create(:bank_account, user: user, bank: bank)
      create(:transaction, user: user, bank_account: bank_account, category: parent_category1, source: :manual)
      create(:transaction, user: user, bank_account: bank_account, category: subcategory1, source: :manual)

      get "/api/v1/categories", headers: auth_headers
      json = JSON.parse(response.body)

      food_category = json["data"]["categories"].find { |c| c["name"] == "Food" }
      expect(food_category["transactions_count"]).to eq(1)

      grocery_subcategory = food_category["children"].find { |c| c["name"] == "Groceries" }
      expect(grocery_subcategory["transactions_count"]).to eq(1)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/categories"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
