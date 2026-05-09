# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Categories - Update", type: :request) do
  path("/api/v1/categories/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Category ID")

    patch("Update a category") do
      tags("Categories")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Update an existing category")

      parameter(
        name: :category, in: :body, schema: {
        type: :object,
        properties: {
          category: {
            type: :object,
            properties: {
              name: { type: :string, description: "Category name" },
              icon: { type: :string, description: "Icon identifier" },
              parent_id: { type: :integer, description: "Parent category ID" }
            }
          }
        },
        example: {
          category: {
            name: "Updated Name",
            icon: "new-icon"
          }
        }
      }
      )

      response("200", "Category updated successfully") do
        schema("$ref" => "#/components/schemas/v1_category_single_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category_record) { create(:category, user: user, name: "Original Name") }
        let(:id) { category_record.id }
        let(:category) do
          {
            category: {
              name: "Updated Name",
              icon: "updated-icon"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["name"]).to eq("Updated Name")
          expect(data["data"]["icon"]).to eq("updated-icon")
          expect(data["message"]).to eq("Category updated successfully")
        end
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/validation_error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:category_record) { create(:category, user: user) }
        let(:id) { category_record.id }
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
        end
      end

      response("404", "Category not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }
        let(:category) do
          {
            category: {
              name: "Test"
            }
          }
        end

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }
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
