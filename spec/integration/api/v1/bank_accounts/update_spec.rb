# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Update", type: :request) do
  path("/api/v1/bank_accounts/{id}") do
    parameter(name: :id, in: :path, type: :integer, description: "Bank Account ID")

    patch("Update a bank account") do
      tags("Bank Accounts")
      consumes("application/json")
      produces("application/json")
      security([Bearer: []])
      description("Update an existing bank account")

      parameter(
        name: :bank_account, in: :body, schema: {
        type: :object,
        properties: {
          bank_account: {
            type: :object,
            properties: {
              bank_id: { type: :integer, description: "Bank ID" },
              account_number: { type: :string, description: "Bank account number" },
              custom_name: { type: :string, description: "Custom display name" },
              currency: { type: :string, description: "Currency code" },
              opening_balance: { type: :number, format: :float, description: "Opening balance amount" },
              opening_balance_date: { type: :string, format: :date, description: "Opening balance date" },
              account_type: { type: :string, enum: [:debit, :credit], description: "Account type" }
            }
          }
        },
        example: {
          bank_account: {
            custom_name: "Updated Account Name",
            opening_balance: 2000.00
          }
        }
      }
      )

      response("200", "Bank account updated successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_account_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank, custom_name: "Old Name") }
        let(:id) { bank_account_record.id }
        let(:bank_account) do
          {
            bank_account: {
              custom_name: "Updated Name",
              opening_balance: 2000.00
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["custom_name"]).to eq("Updated Name")
          expect(data["data"]["opening_balance"]).to eq("2000.0")
          expect(data["message"]).to eq("Bank account updated successfully")
        end
      end

      response("422", "Validation error") do
        schema("$ref" => "#/components/schemas/validation_error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank) }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank) }
        let(:id) { bank_account_record.id }
        let(:bank_account) do
          {
            bank_account: {
              account_number: ""
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      response("404", "Bank account not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :confirmed) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }
        let(:bank_account) do
          {
            bank_account: {
              custom_name: "Test"
            }
          }
        end

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }
        let(:bank_account) do
          {
            bank_account: {
              custom_name: "Test"
            }
          }
        end

        run_test!
      end
    end
  end
end
