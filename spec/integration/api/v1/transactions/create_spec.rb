# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Create", type: :request) do
  path("/api/v1/transactions") do
    post("Create a new transaction") do
      tags("Transactions")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Create a new manual transaction. Only manual transactions can be created via API.")

      parameter(
        name: :transaction, in: :body, schema: {
        type: :object,
        properties: {
          transaction: {
            type: :object,
            properties: {
              bank_account_id: { type: :integer, description: "ID of the bank account" },
              date: { type: :string, format: :date, description: "Transaction date (YYYY-MM-DD)" },
              description: { type: :string, description: "Transaction description (min 4 characters)" },
              amount: { type: :number,
description: "Transaction amount (positive for income, will be adjusted based on type)" },
              transaction_type: { type: :string, enum: ["income", "fixed_expense", "variable_expense"],
description: "Type of transaction" },
              category_id: { type: :integer, description: "ID of the category (optional)" },
              merchant: { type: :string, description: "Merchant name (optional)" },
              reference: { type: :string, description: "Reference number (optional)" },
              transfer_account_id: { type: :integer,
description: "For transfers: destination account ID (optional)" },
              saving_ids: { type: :array, items: { type: :integer },
description: "Link to saving goals (optional)" },
              debt_ids: { type: :array, items: { type: :integer },
description: "Link to debt goals (optional)" }
            },
            required: [:bank_account_id, :date, :description, :amount, :transaction_type]
          }
        }
      }
      )

      response("201", "Transaction created successfully") do
        schema("$ref" => "#/components/schemas/v1_transaction_single_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let(:transaction) do
          {
            transaction: {
              bank_account_id: bank_account.id,
              date: Date.current.to_s,
              description: "Test transaction",
              amount: 100.50,
              transaction_type: "income",
              category_id: category.id
            }
          }
        end

        run_test!
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:transaction) do
          {
            transaction: {
              bank_account_id: bank_account.id,
              date: Date.current.to_s,
              description: "ab",  # Too short
              amount: 100,
              transaction_type: "income"
            }
          }
        end

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:transaction) { { transaction: {} } }

        run_test!
      end
    end
  end
end
