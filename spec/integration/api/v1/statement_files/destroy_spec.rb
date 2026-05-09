# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Destroy", type: :request) do
  path("/api/v1/statement_files/{id}") do
    parameter(name: :id, in: :path, type: :integer, required: true, description: "Statement file ID")

    delete("Delete a statement file") do
      tags("Statement Files")
      produces("application/json")
      security([Bearer: []])
      description(
        "Delete a statement file and all associated statement-sourced transactions. " \
        "Manual transactions are preserved but unlinked."
      )

      response("204", "Statement file deleted successfully") do
        let(:user) { create(:user) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
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
