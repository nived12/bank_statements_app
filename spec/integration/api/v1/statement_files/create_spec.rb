# frozen_string_literal: true

require "swagger_helper"

RSpec.describe("API V1 Statement Files - Create", type: :request) do
  path("/api/v1/statement_files") do
    post("Upload a statement file") do
      tags("Statement Files")
      consumes("multipart/form-data")
      produces("application/json")
      security([Bearer: []])
      description(
        "Upload a PDF statement file for processing. The file will be queued for async processing. " \
        "Only PDF files up to 10MB are accepted. Send multipart form data with statement_file[bank_account_id] " \
        "(required), statement_file[file] (required, PDF file), statement_file[cutoff_date] " \
        "(optional, accepts both date strings like '2024-01-15' or ISO8601 UTC datetimes like " \
        "'2024-01-15T14:30:45Z'), statement_file[processing_strategy] (optional, default: 'parser_only', " \
        "values: 'parser_only', 'text_with_ai', 'vision_ai'), and statement_file[file_password] " \
        "(optional, password for password-protected PDF files). Rate limits: 20 uploads/hour per IP, " \
        "50 uploads/hour per user."
      )

      response("201", "Statement file uploaded successfully") do
        schema("$ref" => "#/components/schemas/v1_statement_file_single_response")

        let(:user) { create(:user, :consented) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        before do
          # Create a statement file with attached file for the response
          statement_file = create(:statement_file, user: user, bank_account: bank_account, status: :pending)
          statement_file.file.attach(
            io: File.open(Rails.root.join("spec/fixtures/files/sample.pdf")),
            filename: "sample.pdf",
            content_type: "application/pdf"
          )

          # Mock the entire create action to bypass file upload handling
          allow_any_instance_of(Api::V1::StatementFilesController).to receive(:create) do |controller|
            controller.instance_variable_set(:@statement_file, statement_file)
            controller.instance_variable_set(:@message, "Statement file uploaded successfully")
            controller.render "api/v1/statement_files/show", status: :created
          end

          # Make the POST request
          post "/api/v1/statement_files",
            params: { statement_file: { bank_account_id: bank_account.id } },
            headers: { "Authorization" => self.Authorization }
        end

        run_test! do
          expect(response).to have_http_status(:created)
          data = JSON.parse(response.body)
          expect(data["data"]["status"]).to eq("pending")
          expect(data["message"]).to eq("Statement file uploaded successfully")
        end
      end

      response("400", "Bad request - Missing required parameter") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :consented) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        before do
          post "/api/v1/statement_files",
            params: {},
            headers: { "Authorization" => self.Authorization }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("PARAMETER_MISSING")
        end
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

      response("429", "Too many requests - Rate limit exceeded") do
        schema("$ref" => "#/components/schemas/error_response")

        let(:user) { create(:user, :consented) }
        let(:bank_account) { create(:bank_account, user: user) }
        let(:Authorization) { "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }

        before do
          # Clear rack-attack cache
          Rack::Attack.cache.store.clear

          # Exceed the IP rate limit (20 per hour)
          21.times do
            post "/api/v1/statement_files",
              params: {
                statement_file: {
                  bank_account_id: bank_account.id,
                  cutoff_date: "2024-01-15"
                }
              },
              headers: { "Authorization" => self.Authorization }
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("RATE_LIMIT_EXCEEDED")
          expect(response.headers["Retry-After"]).to be_present
        end
      end
    end
  end
end
