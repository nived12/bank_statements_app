# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Create", type: :request) do
  path("/api/v1/bank_accounts") do
    post("Create a new bank account") do
      tags("Bank Accounts")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Create a new bank account for the authenticated user")

      parameter(
        name: :bank_account, in: :body, schema: {
        type: :object,
        properties: {
          bank_account: {
            type: :object,
            properties: {
              bank_id: { type: :integer, description: "Bank ID" },
              account_number: { type: :string, description: "Bank account number" },
              custom_name: { type: :string, description: "Custom display name (optional)" },
              currency: { type: :string, description: "Currency code (e.g., MXN, USD)" },
              opening_balance: { type: :number, format: :float, description: "Opening balance amount" },
              opening_balance_date: { type: :string, format: :date,
description: "Opening balance date (YYYY-MM-DD)" },
              account_type: { type: :string, enum: [:debit, :credit],
description: "Account type (debit or credit)" }
            },
            required: [:bank_id, :account_number, :opening_balance_date]
          }
        },
        example: {
          bank_account: {
            bank_id: 1,
            account_number: "1234567890",
            custom_name: "My Savings Account",
            currency: "MXN",
            opening_balance: 1000.50,
            opening_balance_date: "2024-01-01",
            account_type: "debit"
          }
        }
      }
      )

      response("201", "Bank account created successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_account_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account) do
          {
            bank_account: {
              bank_id: bank.id,
              account_number: "1234567890",
              custom_name: "Test Savings",
              currency: "MXN",
              opening_balance: 1000.50,
              opening_balance_date: "2024-01-01",
              account_type: "debit"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["account_number"]).to eq("1234567890")
          expect(data["data"]["custom_name"]).to eq("Test Savings")
          expect(data["message"]).to eq("Bank account created successfully")
        end
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/validation_error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank_account) do
          {
            bank_account: {
              account_number: "1234567890"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
          expect(data["error"]["details"]).to be_present
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:bank) { create(:bank) }
        let(:bank_account) do
          {
            bank_account: {
              bank_id: bank.id,
              account_number: "1234567890",
              opening_balance_date: "2024-01-01"
            }
          }
        end

        run_test!
      end
    end
  end
end
