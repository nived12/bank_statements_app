# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Categories - Destroy", type: :request) do
  path("/api/v1/categories/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Category ID")

    delete("Delete a category") do
      tags("Categories")
      produces("application/json")
      security([Bearer: []])
      description("Delete a category. Categories with subcategories cannot be deleted. Associated transactions will have their category_id nullified.")

      response("200", "Category deleted successfully") do
        schema(
          type: :object,
          properties: {
            message: { type: :string }
          },
          required: [:message]
        )

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category_record) { create(:category, user: user) }
        let(:id) { category_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["message"]).to eq("Category deleted successfully")
        end
      end

      response("422", "Cannot delete category with subcategories") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:parent_category) { create(:category, user: user) }
        let!(:subcategory) { create(:category, user: user, parent: parent_category) }
        let(:id) { parent_category.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("DELETE_NOT_ALLOWED")
          expect(data["error"]["message"]).to eq("Cannot delete category with subcategories")
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
