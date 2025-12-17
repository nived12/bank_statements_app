# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Transactions", type: :request) do
  path("/api/v1/transactions") do
    get("List transactions with pagination and filters") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve paginated list of transactions with optional filters and statistics")

      parameter(name: :page, in: :query, type: :integer, required: false,
                description: "Page number for pagination (default: 1)")
      parameter(name: :page_token, in: :query, type: :integer, required: false,
                description: "Alternative to 'page' parameter for pagination")
      parameter(name: :page_size, in: :query, type: :integer, required: false,
                description: "Number of items per page (default: 20, max: 100)")
      parameter(name: :bank_account_id, in: :query, type: :integer, required: false,
                description: "Filter by bank account ID")
      parameter(name: :statement_file_id, in: :query, type: :integer, required: false,
                description: "Filter by statement file ID")
      parameter(name: :transaction_type, in: :query, type: :string, required: false,
                description: "Filter by transaction type",
                schema: { type: :string, enum: ["income", "fixed_expense", "variable_expense", "transfer"] })
      parameter(name: :from_date, in: :query, type: :string, required: false,
                description: "Filter transactions from this date (YYYY-MM-DD)")
      parameter(name: :to_date, in: :query, type: :string, required: false,
                description: "Filter transactions up to this date (YYYY-MM-DD)")
      parameter(name: :search, in: :query, type: :string, required: false,
                description: "Search in transaction description")
      parameter(name: :sort, in: :query, type: :string, required: false,
                description: "Sort field (default: date)",
                schema: { type: :string, enum: ["date", "amount", "description", "transaction_type", "merchant", "category", "bank_account"] })
      parameter(name: :direction, in: :query, type: :string, required: false,
                description: "Sort direction (default: desc)",
                schema: { type: :string, enum: ["asc", "desc"] })

      response("200", "Transactions retrieved successfully") do
        schema("$ref" => "#/components/schemas/TransactionsListResponse")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let!(:bank_account) { create(:bank_account, user: user) }
        let!(:category) { create(:category, user: user) }
        let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end

    post("Create a new transaction") do
      tags("Transactions")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Create a new manual transaction. Only manual transactions can be created via API.")

      parameter(name: :transaction, in: :body, schema: {
        type: :object,
        properties: {
          transaction: {
            type: :object,
            properties: {
              bank_account_id: { type: :integer, description: "ID of the bank account" },
              date: { type: :string, format: :date, description: "Transaction date (YYYY-MM-DD)" },
              description: { type: :string, description: "Transaction description (min 4 characters)" },
              amount: { type: :number, description: "Transaction amount (positive for income, will be adjusted based on type)" },
              transaction_type: { type: :string, enum: ["income", "fixed_expense", "variable_expense"], description: "Type of transaction" },
              category_id: { type: :integer, description: "ID of the category (optional)" },
              merchant: { type: :string, description: "Merchant name (optional)" },
              reference: { type: :string, description: "Reference number (optional)" },
              transfer_account_id: { type: :integer, description: "For transfers: destination account ID (optional)" },
              saving_ids: { type: :array, items: { type: :integer }, description: "Link to saving goals (optional)" },
              debt_ids: { type: :array, items: { type: :integer }, description: "Link to debt goals (optional)" }
            },
            required: [:bank_account_id, :date, :description, :amount, :transaction_type]
          }
        }
      })

      response("201", "Transaction created successfully") do
        schema("$ref" => "#/components/schemas/TransactionResponse")

        let(:user) { create(:user, :confirmed) }
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
        schema("$ref" => "#/components/schemas/Error")

        let(:user) { create(:user, :confirmed) }
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
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }
        let(:transaction) { { transaction: {} } }

        run_test!
      end
    end
  end

  path("/api/v1/transactions/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Transaction ID")

    get("Get transaction details") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Retrieve detailed information about a specific transaction")

      response("200", "Transaction retrieved successfully") do
        schema("$ref" => "#/components/schemas/TransactionResponse")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }
        let(:id) { transaction.id }

        run_test!
      end

      response("404", "Transaction not found") do
        schema("$ref" => "#/components/schemas/Error")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end

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
        schema("$ref" => "#/components/schemas/TransactionResponse")

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
        schema("$ref" => "#/components/schemas/Error")

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
        schema("$ref" => "#/components/schemas/Error")

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
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }
        let(:transaction) { { transaction: {} } }

        run_test!
      end
    end

    delete("Delete a transaction") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Delete an existing manual transaction. Only manual transactions can be deleted.")

      response("200", "Transaction deleted successfully") do
        schema(type: :object,
               properties: {
                 message: { type: :string }
               })

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }
        let(:id) { transaction.id }

        run_test!
      end

      response("403", "Forbidden - Cannot delete statement file transactions") do
        schema("$ref" => "#/components/schemas/Error")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:statement_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :statement_file) }
        let(:id) { statement_transaction.id }

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end
  end

  path("/api/v1/transactions/summary") do
    get("Get transaction statistics") do
      tags("Transactions")
      produces("application/json")
      security([Bearer: []])
      description("Get transaction summary and statistics with optional filters")

      parameter(name: :bank_account_id, in: :query, type: :integer, required: false,
                description: "Filter by bank account ID")
      parameter(name: :transaction_type, in: :query, type: :string, required: false,
                description: "Filter by transaction type")
      parameter(name: :from_date, in: :query, type: :string, required: false,
                description: "Filter from date (YYYY-MM-DD)")
      parameter(name: :to_date, in: :query, type: :string, required: false,
                description: "Filter to date (YYYY-MM-DD)")

      response("200", "Summary retrieved successfully") do
        schema(type: :object,
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
               })

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:category) { create(:category, user: user) }
        let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual) }

        run_test!
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/Error")

        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
