# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Retry", type: :request) do
  path("/api/v1/statement_files/{id}/retry") do
    parameter(name: :id, in: :path, type: :integer, required: true, description: "Statement file ID")

    post("Retry failed statement file processing") do
      tags("Statement Files")
      produces("application/json")
      security([Bearer: []])
      description(
        "Retry processing for a failed statement file. Only statement files with 'error' status can be retried. " \
        "Resets status to 'pending' and enqueues for processing."
      )

      response("200", "Statement file processing restarted") do
        schema("$ref" => "#/components/schemas/v1_statement_file_single_response")

        let(:user) { create(:user) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:statement_file) do
          create(
            :statement_file, user: user, bank_account: bank_account, status: :error,
            error_message: "Processing failed"
          )
        end
        let(:id) { statement_file.id }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["status"]).to eq("pending")
          expect(data["message"]).to eq("Statement file processing restarted")
        end
      end

      response("422", "Retry not allowed - Statement file status is not 'error'") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, status: :completed) }
        let(:id) { statement_file.id }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test!
      end

      response("404", "Statement file not found") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user) }
        let(:id) { 99999 }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:id) { 1 }
        let(:Authorization) { "Bearer invalid.token" }

        run_test!
      end
    end
  end
end
