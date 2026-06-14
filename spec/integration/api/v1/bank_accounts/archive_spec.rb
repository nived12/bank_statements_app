# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Bank Accounts - Archive/Unarchive", type: :request) do
  path("/api/v1/bank_accounts/{id}/archive") do
    parameter(name: :id, in: :path, type: :integer, description: "Bank Account ID")

    patch("Archive a bank account") do
      tags("Bank Accounts")
      produces("application/json")
      security([Bearer: []])
      description(
        "Soft-delete a bank account using discard. The account is hidden from lists and balance " \
        "totals but its transaction history is preserved. Can be restored with unarchive."
      )

      response("200", "Bank account archived successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_account_single_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank) }
        let(:id) { bank_account_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["archived"]).to be true
          expect(data["data"]["archived_at"]).to be_present
        end
      end

      response("404", "Bank account not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("NOT_FOUND")
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end
  end

  path("/api/v1/bank_accounts/{id}/unarchive") do
    parameter(name: :id, in: :path, type: :integer, description: "Bank Account ID")

    patch("Unarchive a bank account") do
      tags("Bank Accounts")
      produces("application/json")
      security([Bearer: []])
      description("Restore a previously archived bank account. The account will reappear in lists and balance totals.")

      response("200", "Bank account unarchived successfully") do
        schema("$ref" => "#/components/schemas/v1_bank_account_single_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:bank) { create(:bank, name: "Test Bank", code: "test") }
        let(:bank_account_record) { create(:bank_account, user: user, bank: bank, discarded_at: Time.current) }
        let(:id) { bank_account_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["archived"]).to be false
          expect(data["data"]["archived_at"]).to be_nil
        end
      end

      response("404", "Bank account not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
        let(:id) { 999999 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("NOT_FOUND")
        end
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }
        let(:id) { 1 }

        run_test!
      end
    end
  end
end
