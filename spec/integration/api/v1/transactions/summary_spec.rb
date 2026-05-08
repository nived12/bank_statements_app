# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions - Summary", type: :request) do
  path("/api/v1/transactions/summary") do
    get("Get transaction statistics") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Get transaction summary and statistics with optional filters")

      parameter(
        name: :bank_account_id, in: :query, type: :integer, required: false,
        description: "Filter by bank account ID"
      )
      parameter(
        name: :transaction_type, in: :query, type: :string, required: false,
        description: "Filter by transaction type"
      )
      parameter(
        name: :from_date, in: :query, type: :string, required: false,
        description: "Filter from date (YYYY-MM-DD)"
      )
      parameter(
        name: :to_date, in: :query, type: :string, required: false,
        description: "Filter to date (YYYY-MM-DD)"
      )

      response("200", "Summary retrieved successfully") do
        schema(
          type: :object,
          properties: {
                      data: {
                        type: :object,
                        properties: {
                          stats: {
                            type: :object,
                            properties: {
                              total_transactions: { type: :integer },
                              income_total: { type: :number },
                              expenses_total: { type: :number },
                              equity_total: { type: :number },
                              income_count: { type: :integer },
                              fixed_expense_count: { type: :integer },
                              variable_expense_count: { type: :integer },
                              category_count: { type: :integer }
                            }
                          }
                        }
                      },
                      meta: {
                        type: :object,
                        properties: {
                          filters: {
                            type: :object,
                            properties: {
                              bank_account_id: { type: :integer, nullable: true },
                              transaction_type: { type: :string, nullable: true },
                              from_date: { type: :string, nullable: true },
                              to_date: { type: :string, nullable: true }
                            }
                          }
                        }
                      }
                    }
        )

        let(:user) { create(:user, :consented) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) do
          create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual)
        end

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
