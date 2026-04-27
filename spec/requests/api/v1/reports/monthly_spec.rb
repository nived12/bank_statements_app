# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Reports - Monthly", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:category) { create(:category, user: user) }

  before do
    create(
      :transaction, user: user, bank_account: bank_account, statement_file: statement_file,
      category: category, date: Date.new(2025, 3, 10), amount: -500.0, transaction_type: "variable_expense"
    )
    create(
      :transaction, user: user, bank_account: bank_account, statement_file: statement_file,
      category: category, date: Date.new(2025, 3, 15), amount: 2000.0, transaction_type: "income"
    )
  end

  describe "GET /api/v1/reports/monthly" do
    context "when authenticated" do
      it "returns 200 ok with pdf content type" do
        get "/api/v1/reports/monthly", params: { year: 2025, month: 3 }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/pdf")
      end

      it "returns a non-empty binary response" do
        get "/api/v1/reports/monthly", params: { year: 2025, month: 3 }, headers: auth_headers

        expect(response.body.bytesize).to be > 1000
        expect(response.body.start_with?("%PDF")).to be true
      end

      it "returns attachment content-disposition" do
        get "/api/v1/reports/monthly", params: { year: 2025, month: 3 }, headers: auth_headers

        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include("vittio-reporte-2025-03.pdf")
      end

      it "works for a month with no transactions (empty report)" do
        get "/api/v1/reports/monthly", params: { year: 2020, month: 1 }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/pdf")
        expect(response.body.start_with?("%PDF")).to be true
      end

      context "with invalid period" do
        it "returns 422 for month out of range" do
          get "/api/v1/reports/monthly", params: { year: 2025, month: 13 }, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("INVALID_PERIOD")
        end

        it "returns 422 for year out of range" do
          get "/api/v1/reports/monthly", params: { year: 1999, month: 3 }, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("INVALID_PERIOD")
        end

        it "returns 422 for missing year" do
          get "/api/v1/reports/monthly", params: { month: 3 }, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns 422 for missing month" do
          get "/api/v1/reports/monthly", params: { year: 2025 }, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "with invalid format" do
        it "returns 422 for unsupported report_format" do
          get "/api/v1/reports/monthly", params: { year: 2025, month: 3, report_format: "csv" }, headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("INVALID_FORMAT")
        end
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/reports/monthly", params: { year: 2025, month: 3 }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
