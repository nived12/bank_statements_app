# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Categories - Index", type: :request) do
  path("/api/v1/categories") do
    get("List all categories") do
      tags("Categories")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve hierarchical list of categories with their subcategories and transaction counts")

      response("200", "Categories retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_categories_list_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["categories"]).to be_an(Array)
          expect(data["data"]["categories"].first).to have_key("children")
          expect(data["data"]["categories"].first).to have_key("transactions_count")
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
