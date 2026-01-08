# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Create", type: :request) do
  path("/api/v1/statement_files") do
    post("Upload a statement file") do
      tags("Statement Files")
      consumes("multipart/form-data")
      produces("application/json")
      security([Bearer: []])
      description("Upload a PDF statement file for processing. The file will be queued for async processing. Only PDF files up to 10MB are accepted. Send multipart form data with statement_file[bank_account_id], statement_file[file], statement_file[cutoff_date] (accepts both date strings like '2024-01-15' or ISO8601 UTC datetimes like '2024-01-15T14:30:45Z'), and statement_file[ai_enabled] (optional, default: false).")

      response("201", "Statement file uploaded successfully") do
        schema("$ref" => "#/components/schemas/v1_statement_file_single_response")

        let(:user) { create(:user, :confirmed) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        before do
          post "/api/v1/statement_files",
            params: {
              statement_file: {
                bank_account_id: bank_account.id,
                file: Rack::Test::UploadedFile.new(
                  Rails.root.join("spec/fixtures/files/sample.pdf"),
                  "application/pdf"
                ),
                cutoff_date: "2024-01-15",
                ai_enabled: true
              }
            },
            headers: { "Authorization" => self.Authorization }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["status"]).to eq("pending")
          expect(data["message"]).to eq("Statement file uploaded successfully")
        end
      end

      response("422", "Validation error - Invalid file type or size") do
        schema("$ref" => "#/components/schemas/validation_error_response")

        let(:user) { create(:user, :confirmed) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        before do
          post "/api/v1/statement_files",
            params: {
              statement_file: {
                bank_account_id: bank_account.id,
                file: Rack::Test::UploadedFile.new(
                  StringIO.new("Not a PDF"), "text/plain",
                  original_filename: "test.txt"
                ),
                cutoff_date: "2024-01-15"
              }
            },
            headers: { "Authorization" => self.Authorization }
        end

        run_test!
      end

      response("401", "Unauthorized - Invalid or missing token") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:Authorization) { "Bearer invalid.token" }

        before do
          post "/api/v1/statement_files",
            params: {
              statement_file: {
                bank_account_id: 1,
                cutoff_date: "2024-01-15"
              }
            },
            headers: { "Authorization" => self.Authorization }
        end

        run_test!
      end
    end
  end
end
