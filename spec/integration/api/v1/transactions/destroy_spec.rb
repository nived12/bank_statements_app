# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Destroy", type: :request) do
  path("/api/v1/transactions/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Transaction ID")

    delete("Delete a transaction") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Delete an existing manual transaction. Only manual transactions can be deleted.")

      response("200", "Transaction deleted successfully") do
        schema(
          type: :object,
          properties: {
                      message: { type: :string }
                    }
        )

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) do
          create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual)
        end
        let(:id) { transaction.id }

        run_test!
      end

      response("403", "Forbidden - Cannot delete statement file transactions") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:statement_transaction) do
          create(:transaction, user: user, bank_account: bank_account, category: category, source: :statement_file)
        end
        let(:id) { statement_transaction.id }

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
