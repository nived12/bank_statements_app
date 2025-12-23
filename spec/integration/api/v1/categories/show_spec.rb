# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Categories - Show", type: :request) do
  path("/api/v1/categories/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Category ID")

    get("Get category details") do
      tags("Categories")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve a single category with its subcategories and transaction count")

      response("200", "Category retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_category_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category_record) { create(:category, user: user, name: "Test Category") }
        let(:id) { category_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["id"]).to eq(category_record.id)
          expect(data["data"]["name"]).to eq("Test Category")
          expect(data["data"]["children"]).to be_an(Array)
        end
      end

      response("404", "Category not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("CATEGORY_NOT_FOUND")
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end
  end
end
