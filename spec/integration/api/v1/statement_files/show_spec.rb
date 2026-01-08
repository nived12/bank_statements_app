# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Show", type: :request) do
  path("/api/v1/statement_files/{id}") do
    parameter(name: :id, in: :path, type: :integer, required: true, description: "Statement file ID")

    get("Get statement file details") do
      tags("Statement Files")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve details of a specific statement file including processing status, bank account, and transaction count.")

      response("200", "Statement file retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_statement_file_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
        let(:id) { statement_file.id }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["id"]).to eq(statement_file.id)
        end
      end

      response("404", "Statement file not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:id) { 1 }
        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
