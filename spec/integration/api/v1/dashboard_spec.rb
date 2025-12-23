# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Dashboard", type: :request) do
  path("/api/v1/dashboard") do
    get("Get dashboard overview") do
      tags("Dashboard")
      produces("application/json")
      security([Bearer: []])
      description("Get comprehensive dashboard data including account balances, transactions, and statistics")

      parameter(name: :month, in: :query, type: :string, required: false,
                description: "Filter data by month (format: YYYY-MM). Defaults to current month.",
                schema: { type: :string, pattern: "^\\d{4}-\\d{2}$", example: "2024-12" })

      response("200", "Dashboard data retrieved successfully") do
        schema(type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     summary: {
                       type: :object,
                       properties: {
                         total_balance: { type: :string, description: "Total balance across all accounts" },
                         total_transactions: { type: :integer, description: "Total number of transactions" },
                         total_statements: { type: :integer, description: "Total number of statement files" },
                         selected_month: { type: :string, description: "Selected month in YYYY-MM format" }
                       },
                       required: [:total_balance, :total_transactions, :total_statements, :selected_month]
                     },
                     monthly_summary: {
                       type: :object,
                       properties: {
                         total_income: { type: :integer, description: "Total income for the month" },
                         total_expenses: { type: :integer, description: "Total expenses for the month" },
                         net_income: { type: :integer, description: "Net income (income - expenses)" },
                         income_count: { type: :integer, description: "Number of income transactions" },
                         expense_count: { type: :integer, description: "Number of expense transactions" }
                       },
                       required: [:total_income, :total_expenses, :net_income, :income_count, :expense_count]
                     },
                     monthly_stats: {
                       type: :object,
                       properties: {
                         average_transaction: { type: :integer, description: "Average transaction amount" },
                         largest_expense: { type: :string, description: "Largest expense transaction" },
                         largest_income: { type: :string, description: "Largest income transaction" },
                         daily_average: { type: :integer, description: "Average daily spending" }
                       },
                       required: [:average_transaction, :largest_expense, :largest_income, :daily_average]
                     },
                     bank_accounts: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           name: { type: :string, description: "Display name of the account" },
                           custom_name: { type: :string, nullable: true },
                           bank_name: { type: :string },
                           account_type: { type: :string, enum: [:checking, :savings, :credit_card, :investment, :other, :debit] },
                           opening_balance: { type: :string },
                           balance: { type: :string, description: "Current effective balance" },
                           currency: { type: :string }
                         }
                       }
                     },
                     bank_summaries: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           account_id: { type: :integer },
                           account_name: { type: :string },
                           bank_name: { type: :string },
                           balance: { type: :string },
                           transaction_count: { type: :integer },
                           recent_activity: { type: :string, nullable: true },
                           last_processed: { type: :string, nullable: true },
                           status: { type: :string, nullable: true }
                         }
                       }
                     },
                     recent_transactions: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           date: { type: :string },
                           description: { type: :string },
                           amount: { type: :number, description: "Transaction amount (negative for expenses)" },
                           transaction_type: { type: :string, enum: [:income, :fixed_expense, :variable_expense, :transfer_in, :transfer_out] },
                           bank_account: {
                             type: :object,
                             properties: {
                               id: { type: :integer },
                               name: { type: :string }
                             }
                           },
                           category: {
                             type: :object,
                             properties: {
                               id: { type: :integer },
                               name: { type: :string },
                               icon: { type: :string, nullable: true }
                             }
                           }
                         }
                       }
                     },
                     recent_statement_files: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           filename: { type: :string },
                           status: { type: :string },
                           processed_at: { type: :string, format: "date-time", nullable: true },
                           created_at: { type: :string, format: "date-time" },
                           bank_account: {
                             type: :object,
                             properties: {
                               id: { type: :integer },
                               name: { type: :string }
                             }
                           }
                         }
                       }
                     },
                     category_summary: {
                       type: :object,
                       properties: {
                         categories: {
                           type: :array,
                           items: {
                             type: :object,
                             properties: {
                               name: { type: :string },
                               amount: { type: :string }
                             }
                           }
                         },
                         has_data: { type: :boolean }
                       }
                     },
                     spending_trends: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           month: { type: :string },
                           total_expenses: { type: :string, nullable: true },
                           total_income: { type: :string, nullable: true },
                           net_income: { type: :string, nullable: true }
                         }
                       }
                     },
                     available_months: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           value: { type: :string, description: "Month value in YYYY-MM format" },
                           label: { type: :string, description: "Formatted month label" }
                         }
                       }
                     }
                   },
                   required: [:summary, :monthly_summary, :monthly_stats, :bank_accounts, :bank_summaries,
                              :recent_transactions, :recent_statement_files, :category_summary,
                              :spending_trends, :available_months]
                 }
               },
               required: [:data])

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let!(:bank) { create(:bank, name: "Test Bank") }
        let!(:bank_account) { create(:bank_account, user: user, bank: bank, opening_balance: 1000) }
        let!(:category) { create(:category, user: user, name: "Food") }
        let!(:transaction1) do
          create(:transaction, user: user, bank_account: bank_account, category: category,
                                amount: -50, transaction_type: "variable_expense", date: Date.current)
        end
        let!(:transaction2) do
          create(:transaction, user: user, bank_account: bank_account, category: category,
                                amount: 100, transaction_type: "income", date: Date.current)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["summary"]).to be_present
          expect(data["data"]["bank_accounts"]).to be_an(Array)
          expect(data["data"]["recent_transactions"]).to be_an(Array)
        end
      end

      response("401", "Unauthorized") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token.here" }

        run_test!
      end
    end
  end
end
