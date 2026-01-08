# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Create", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:auth_headers) do
    {
      "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}"
    }
  end
  let(:pdf_file) do
    fixture_path = Rails.root.join("spec/fixtures/files/sample.pdf")
    Rack::Test::UploadedFile.new(fixture_path, "application/pdf")
  end

  describe "POST /api/v1/statement_files" do
    it "creates statement file with valid params" do
      expect {
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              ai_enabled: true,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      }.to change(StatementFile, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to be_present
      expect(json["data"]["status"]).to eq("pending")
      expect(json["data"]["ai_enabled"]).to eq(true)
      expect(json["message"]).to eq("Statement file uploaded successfully")
    end

    it "enqueues StatementIngestJob" do
      expect {
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      }.to have_enqueued_job(StatementIngestJob)
    end

    it "converts date string to end-of-day UTC" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      statement_file = StatementFile.last
      expect(statement_file.cutoff_date.hour).to eq(23)
      expect(statement_file.cutoff_date.min).to eq(59)
      expect(statement_file.cutoff_date.sec).to eq(59)
    end

    it "preserves UTC datetime when provided instead of converting" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            cutoff_date: "2024-01-15T14:30:45Z"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      statement_file = StatementFile.last
      expect(statement_file.cutoff_date.hour).to eq(14)
      expect(statement_file.cutoff_date.min).to eq(30)
      expect(statement_file.cutoff_date.sec).to eq(45)
    end

    it "preserves midnight datetime when explicitly provided" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            cutoff_date: "2024-01-15T00:00:00Z"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      statement_file = StatementFile.last
      # Should keep midnight as provided, not convert to end-of-day
      expect(statement_file.cutoff_date.hour).to eq(0)
      expect(statement_file.cutoff_date.min).to eq(0)
      expect(statement_file.cutoff_date.sec).to eq(0)
    end

    it "defaults ai_enabled to false when not provided" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["ai_enabled"]).to eq(false)
    end

    it "handles boolean string conversion for ai_enabled" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            ai_enabled: "true",
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["ai_enabled"]).to eq(true)
    end

    it "returns error when file is missing" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("FILE_REQUIRED")
      expect(json["error"]["message"]).to eq("File is required")
    end

    it "returns error when file is not a PDF" do
      txt_file = Rack::Test::UploadedFile.new(
        StringIO.new("Not a PDF"),
        "text/plain",
        original_filename: "test.txt"
      )

      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: txt_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("INVALID_FILE_TYPE")
      expect(json["error"]["message"]).to eq("Only PDF files are supported")
    end

    it "returns error when file exceeds 10MB" do
      large_content = "x" * (11 * 1024 * 1024) # 11MB
      large_file = Rack::Test::UploadedFile.new(
        StringIO.new(large_content),
        "application/pdf",
        original_filename: "large.pdf"
      )

      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: large_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("FILE_TOO_LARGE")
      expect(json["error"]["message"]).to include("10MB")
    end

    it "returns validation error when bank_account_id is missing" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            file: pdf_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            cutoff_date: "2024-01-15"
          }
        }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
