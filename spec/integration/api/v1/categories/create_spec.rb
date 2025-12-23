# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Categories - Create", type: :request) do
  path("/api/v1/categories") do
    post("Create a new category") do
      tags("Categories")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Create a new category or subcategory")

      parameter(name: :category, in: :body, schema: {
        type: :object,
        properties: {
          category: {
            type: :object,
            properties: {
              name: { type: :string, description: "Category name" },
              icon: { type: :string, description: "Icon identifier (optional)" },
              parent_id: { type: :integer, description: "Parent category ID for subcategories (optional)" }
            },
            required: [:name]
          }
        },
        example: {
          category: {
            name: "Groceries",
            icon: "shopping-cart",
            parent_id: 1
          }
        }
      })

      response("201", "Category created successfully") do
        schema("$ref" => "#/components/schemas/v1_category_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category) do
          {
            category: {
              name: "Test Category",
              icon: "test-icon"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["name"]).to eq("Test Category")
          expect(data["data"]["icon"]).to eq("test-icon")
          expect(data["message"]).to eq("Category created successfully")
        end
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/validation_error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category) do
          {
            category: {
              name: ""
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(data["error"]["details"]).to be_present
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:category) do
          {
            category: {
              name: "Test"
            }
          }
        end

        run_test!
      end
    end
  end
end
