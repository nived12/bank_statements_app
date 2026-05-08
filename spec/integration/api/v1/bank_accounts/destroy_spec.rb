# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Destroy", type: :request) do
  path("/api/v1/bank_accounts/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Bank Account ID")

    delete("Delete a bank account") do
      tags("Bank Accounts")
      produces("application/json")
      security([Bearer: []])
      description("Delete a bank account. Associated transactions will also be deleted (cascade).")

      response("204", "Bank account deleted successfully") do
        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank) }
        let(:id) { bank_account_record.id }

        run_test!
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
