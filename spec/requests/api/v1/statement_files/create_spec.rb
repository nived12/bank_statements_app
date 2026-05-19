# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Create", type: :request do
  let(:user) { create(:user) }
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
              processing_strategy: "text_with_ai",
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      }.to change(StatementFile, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to be_present
      expect(json["data"]["status"]).to eq("pending")
      expect(json["data"]["processing_strategy"]).to eq("text_with_ai")
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

    it "defaults processing_strategy to vision_ai when not provided" do
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
      expect(json["data"]["processing_strategy"]).to eq("vision_ai")
    end

    it "accepts vision_ai processing strategy" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            processing_strategy: "vision_ai",
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["processing_strategy"]).to eq("vision_ai")
    end

    it "defaults to vision_ai for invalid processing_strategy" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            file: pdf_file,
            processing_strategy: "invalid_strategy",
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["processing_strategy"]).to eq("vision_ai")
    end

    it "returns validation error when file is missing" do
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account.id,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
      file_error = json["error"]["details"].find { |e| e["field"] == "file" }
      expect(file_error).to be_present
      expect(file_error["message"]).to be_present
    end

    it "returns validation error when file is not a PDF" do
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

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
      file_error = json["error"]["details"].find { |e| e["field"] == "file" }
      expect(file_error).to be_present
      expect(file_error["message"]).to include("must be a PDF")
    end

    it "returns validation error when file exceeds 10MB" do
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

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
      file_error = json["error"]["details"].find { |e| e["field"] == "file" }
      expect(file_error).to be_present
      expect(file_error["message"]).to include("too large")
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

      expect(response).to have_http_status(:unprocessable_content)
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

    context "when user email is not confirmed" do
      let(:unconfirmed_headers) do
        u = create(:user, confirmed_at: nil)
        { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(u).payload[:access_token]}" }
      end

      it "returns 403 EMAIL_NOT_CONFIRMED" do
        post "/api/v1/statement_files",
          params: { statement_file: { bank_account_id: bank_account.id } },
          headers: unconfirmed_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("EMAIL_NOT_CONFIRMED")
      end
    end

    context "when upload access is denied (subscription gating)" do
      it "returns 403 with reason trial_ended when trial has ended" do
        user.update_columns(trial_ends_at: 1.day.ago)

        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("SUBSCRIPTION_REQUIRED")
        expect(json["error"]["reason"]).to eq("trial_ended")
        expect(json["error"]["message"]).to be_present
      end

      it "returns 403 with reason payment_failed when past_due" do
        user.update_column(:trial_ends_at, nil)
        create(:pay_subscription, :past_due, customer: create(:pay_customer, owner: user))

        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("SUBSCRIPTION_REQUIRED")
        expect(json["error"]["reason"]).to eq("payment_failed")
        expect(json["error"]["message"]).to be_present
      end

      it "returns 403 with reason subscription_required when subscription cancelled" do
        user.update_column(:trial_ends_at, nil)
        create(:pay_subscription, :canceled, customer: create(:pay_customer, owner: user))

        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("SUBSCRIPTION_REQUIRED")
        expect(json["error"]["reason"]).to eq("subscription_required")
        expect(json["error"]["message"]).to be_present
      end

      it "returns 201 when user has premium plan active" do
        user.update_column(:trial_ends_at, nil)
        create(:pay_subscription, customer: create(:pay_customer, owner: user))

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
      end
    end
  end
end
