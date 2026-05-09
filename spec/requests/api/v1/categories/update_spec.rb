# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Categories - Update", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "PATCH /api/v1/categories/:id" do
    let(:category) { create(:category, user: user, name: "Old Name") }
    let(:update_params) do
      {
        category: {
          name: "New Name",
          icon: "new-icon"
        }
      }
    end

    it "updates category successfully" do
      patch "/api/v1/categories/#{category.id}", params: update_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["name"]).to eq("New Name")
      expect(json["data"]["icon"]).to eq("new-icon")
      expect(json["message"]).to eq("Category updated successfully")
    end

    it "returns validation errors for invalid update" do
      invalid_params = {
        category: {
          name: ""
        }
      }

      patch "/api/v1/categories/#{category.id}", params: invalid_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to update category")
    end

    it "returns 404 for non-existent category" do
      patch "/api/v1/categories/999999", params: update_params, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/categories/#{category.id}", params: update_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
