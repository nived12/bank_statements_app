# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Show", type: :request) do
  path("/api/v1/transactions/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Transaction ID")

    get("Get transaction details") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve detailed information about a specific transaction")

      response("200", "Transaction retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_transaction_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }
        let(:id) { transaction.id }

        run_test!
      end

      response("404", "Transaction not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end
  end
end
