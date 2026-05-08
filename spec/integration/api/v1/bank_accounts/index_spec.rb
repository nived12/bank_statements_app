# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Index", type: :request) do
  path("/api/v1/bank_accounts") do
    get("List all bank accounts") do
      tags("Bank Accounts")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve list of all bank accounts for the authenticated user with bank details and transaction counts.")

      response("200", "Bank accounts retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_accounts_list_response")

        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["bank_accounts"]).to be_an(Array)
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
