# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Show", type: :request) do
  path("/api/v1/bank_accounts/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Bank Account ID")

    get("Get bank account details") do
      tags("Bank Accounts")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve a single bank account with its bank details and transaction count")

      response("200", "Bank account retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_account_single_response")

        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank, custom_name: "Test Account") }
        let(:id) { bank_account_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["id"]).to eq(bank_account_record.id)
          expect(data["data"]["custom_name"]).to eq("Test Account")
          expect(data["data"]["bank"]).to be_present
          expect(data["data"]["bank"]["id"]).to eq(bank.id)
        end
      end

      response("404", "Bank account not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("NOT_FOUND")
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
