# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Rate Limiting", type: :request do
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

  before do
    # Clear rack-attack cache before each test
    Rack::Attack.cache.store.clear
  end

  describe "IP-based rate limiting" do
    it "allows requests within the IP rate limit" do
      5.times do
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    it "blocks requests exceeding the IP rate limit" do
      # Make 21 requests (limit is 20 per hour)
      21.times do |i|
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers

        if i < 20
          expect(response).not_to have_http_status(:too_many_requests)
        end
      end

      # The 21st request should be rate limited
      expect(response).to have_http_status(:too_many_requests)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("RATE_LIMIT_EXCEEDED")
      expect(json["error"]["message"]).to include("Rate limit exceeded")
      expect(response.headers["Retry-After"]).to be_present
    end

    it "returns correct retry-after header when rate limited" do
      # Exceed the rate limit
      21.times do
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      end

      expect(response).to have_http_status(:too_many_requests)
      retry_after = response.headers["Retry-After"].to_i
      expect(retry_after).to be > 0
      expect(retry_after).to be <= 3600 # Within 1 hour
    end
  end

  describe "User-based rate limiting" do
    it "enforces IP limit even for different authenticated users from same IP" do
      user2 = create(:user, :confirmed)
      bank_account2 = create(:bank_account, user: user2)
      auth_headers2 = {
        "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user2).payload[:access_token]}"
      }

      # User 1 makes 20 requests (hitting IP limit)
      20.times do
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      end

      # User 2 from the same IP should also be rate limited (IP limit applies first)
      post "/api/v1/statement_files",
        params: {
          statement_file: {
            bank_account_id: bank_account2.id,
            file: pdf_file,
            cutoff_date: "2024-01-15"
          }
        },
        headers: auth_headers2

      expect(response).to have_http_status(:too_many_requests)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("RATE_LIMIT_EXCEEDED")
    end

    it "blocks authenticated user exceeding the user rate limit" do
      # The user limit is 50 per hour, but IP limit is 20
      # So this test verifies the IP limit triggers first
      21.times do
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      end

      expect(response).to have_http_status(:too_many_requests)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("RATE_LIMIT_EXCEEDED")
    end
  end

  describe "Rate limit error response format" do
    it "returns proper JSON error structure" do
      # Exceed the rate limit
      21.times do
        post "/api/v1/statement_files",
          params: {
            statement_file: {
              bank_account_id: bank_account.id,
              file: pdf_file,
              cutoff_date: "2024-01-15"
            }
          },
          headers: auth_headers
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json).to have_key("error")
      expect(json["error"]).to have_key("message")
      expect(json["error"]).to have_key("code")
      expect(json["error"]).to have_key("retry_after")
      expect(json["error"]["code"]).to eq("RATE_LIMIT_EXCEEDED")
    end
  end
end
