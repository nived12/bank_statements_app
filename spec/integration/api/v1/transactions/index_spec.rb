# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Index", type: :request) do
  path("/api/v1/transactions") do
    get("List transactions with pagination and filters") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve paginated list of transactions with optional filters")

      parameter(
        name: :page, in: :query, type: :integer, required: false,
        description: "Page number for pagination (default: 1)"
      )
      parameter(
        name: :page_token, in: :query, type: :integer, required: false,
        description: "Alternative to 'page' parameter for pagination"
      )
      parameter(
        name: :page_size, in: :query, type: :integer, required: false,
        description: "Number of items per page (default: 20, max: 100)"
      )
      parameter(
        name: :bank_account_id, in: :query, type: :integer, required: false,
        description: "Filter by bank account ID"
      )
      parameter(
        name: :statement_file_id, in: :query, type: :integer, required: false,
        description: "Filter by statement file ID"
      )
      parameter(
        name: :transaction_type, in: :query, type: :string, required: false,
        description: "Filter by transaction type",
        schema: { type: :string, enum: ["income", "fixed_expense", "variable_expense", "transfer"] }
      )
      parameter(
        name: :from_date, in: :query, type: :string, required: false,
        description: "Filter transactions from this date (YYYY-MM-DD)"
      )
      parameter(
        name: :to_date, in: :query, type: :string, required: false,
        description: "Filter transactions up to this date (YYYY-MM-DD)"
      )
      parameter(
        name: :search, in: :query, type: :string, required: false,
        description: "Search in transaction description"
      )
      parameter(
        name: :sort, in: :query, type: :string, required: false,
        description: "Sort field (default: date)",
        schema: { type: :string, enum: ["date", "amount", "description", "transaction_type", "merchant", "category", "bank_account"] }
      )
      parameter(
        name: :direction, in: :query, type: :string, required: false,
        description: "Sort direction (default: desc)",
        schema: { type: :string, enum: ["asc", "desc"] }
      )

      response("200", "Transactions retrieved successfully") do
        schema("$ref" => "#/components/schemas/v1_transactions_list_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let!(:bank_account) { create(:bank_account, user: user) }
        let!(:category) { create(:category, user: user) }
        let!(:transaction) {
 create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
