# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Update", type: :request) do
  path("/api/v1/transactions/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Transaction ID")

    patch("Update a transaction") do
      tags("Transactions")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Update an existing manual transaction. Only manual transactions can be updated.")

      parameter(name: :transaction, in: :body, schema: {
        type: :object,
        properties: {
          transaction: {
            type: :object,
            properties: {
              description: { type: :string, description: "Transaction description" },
              amount: { type: :number, description: "Transaction amount" },
              category_id: { type: :integer, description: "Category ID" },
              merchant: { type: :string, description: "Merchant name" },
              reference: { type: :string, description: "Reference number" }
            }
          }
        }
      })

      response("200", "Transaction updated successfully") do
        schema("$ref" => "#/components/schemas/v1_transaction_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:existing_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }
        let(:id) { existing_transaction.id }
        let(:transaction) do
          {
            transaction: {
              description: "Updated description"
            }
          }
        end

        run_test!
      end

      response("403", "Forbidden - Cannot update statement file transactions") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:statement_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :statement_file) }
        let(:id) { statement_transaction.id }
        let(:transaction) do
          {
            transaction: {
              description: "Trying to update"
            }
          }
        end

        run_test!
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:existing_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }
        let(:id) { existing_transaction.id }
        let(:transaction) do
          {
            transaction: {
              description: "ab"  # Too short
            }
          }
        end

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }
        let(:transaction) { { transaction: {} } }

        run_test!
      end
    end
  end
end
