# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Categories - Create", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "POST /api/v1/categories" do
    let(:valid_params) do
      {
        category: {
          name: "New Category",
          icon: "shopping-cart"
        }
      }
    end

    it "creates a new category successfully" do
      initial_count = user.categories.count

      post "/api/v1/categories", params: valid_params, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["name"]).to eq("New Category")
      expect(json["data"]["icon"]).to eq("shopping-cart")
      expect(json["message"]).to eq("Category created successfully")
      expect(user.categories.count).to eq(initial_count + 1)
    end

    it "creates a category with color" do
      params_with_color = { category: { name: "Transport", icon: "car", color: "#6366f1" } }
      post "/api/v1/categories", params: params_with_color, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["color"]).to eq("#6366f1")
    end

    it "creates a subcategory successfully" do
      parent = create(:category, user: user, name: "Food")
      initial_count = user.categories.count

      subcategory_params = {
        category: {
          name: "Groceries",
          parent_id: parent.id
        }
      }

      post "/api/v1/categories", params: subcategory_params, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["name"]).to eq("Groceries")
      expect(json["data"]["parent_id"]).to eq(parent.id)
      expect(user.categories.count).to eq(initial_count + 1)
    end

    it "returns validation errors for invalid category" do
      invalid_params = {
        category: {
          name: ""
        }
      }

      post "/api/v1/categories", params: invalid_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to create category")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/categories", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "when user email is not confirmed" do
      let(:unconfirmed_headers) do
        u = create(:user)
        { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(u).payload[:access_token]}" }
      end

      it "returns 403 EMAIL_NOT_CONFIRMED" do
        post "/api/v1/categories", params: valid_params, headers: unconfirmed_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("EMAIL_NOT_CONFIRMED")
      end
    end
  end
end
