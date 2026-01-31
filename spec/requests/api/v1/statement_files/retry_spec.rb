# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Retry", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:other_user) { create(:user, :confirmed) }
  let(:auth_headers) do
    {
      "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}"
    }
  end

  describe "POST /api/v1/statement_files/:id/retry" do
    it "retries failed processing" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error,
        error_message: "Processing failed"
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["status"]).to eq("pending")
      expect(json["data"]["error_message"]).to be_nil
      expect(json["message"]).to eq("Statement file processing restarted")
    end

    it "resets status to pending" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers

      statement_file.reload
      expect(statement_file.status).to eq("pending")
    end

    it "clears error_message" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error,
        error_message: "Some error"
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers

      statement_file.reload
      expect(statement_file.error_message).to be_nil
    end

    it "clears processed_at timestamp" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error,
        processed_at: 1.hour.ago
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers

      statement_file.reload
      expect(statement_file.processed_at).to be_nil
    end

    it "enqueues StatementIngestJob" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error
      )

      expect {
        post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers
      }.to have_enqueued_job(StatementIngestJob).with(statement_file.id)
    end

    it "returns error if status is not error" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :completed
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("RETRY_NOT_ALLOWED")
      expect(json["error"]["message"]).to eq("Only failed statement files can be retried")
    end

    it "returns 404 for non-existent statement file" do
      post "/api/v1/statement_files/99999/retry", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for other user's statement file" do
      other_bank_account = create(:bank_account, user: other_user)
      other_statement = create(
        :statement_file,
        user: other_user,
        bank_account: other_bank_account,
        status: :error
      )

      post "/api/v1/statement_files/#{other_statement.id}/retry", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(
        :statement_file,
        user: user,
        bank_account: bank_account,
        status: :error
      )

      post "/api/v1/statement_files/#{statement_file.id}/retry"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
