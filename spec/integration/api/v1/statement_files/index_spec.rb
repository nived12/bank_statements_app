# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Index", type: :request) do
  path("/api/v1/statement_files") do
    get("List all statement files") do
      tags("Statement Files")
      produces("application/json")
      security([Bearer: []])
      description(
        "Retrieve paginated list of statement files for the authenticated user with " \
        "bank account details and processing status."
      )

      parameter(name: :page, in: :query, type: :integer, required: false, description: "Page number (default: 1)")
      parameter(
        name: :page_size, in: :query, type: :integer, required: false,
        description: "Items per page (default: 20, max: 100)"
      )

      response("200", "Statement files retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_statement_files_list_response")

        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["statement_files"]).to be_an(Array)
          expect(data["meta"]["pagination"]).to be_present
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
