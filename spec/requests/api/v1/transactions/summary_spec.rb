# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Summary", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v1/transactions/summary" do
    let!(:transactions) do
      [
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: 1000.0, transaction_type: "income", source: :manual),
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: -250.0, transaction_type: "variable_expense", source: :manual)
      ]
    end

    it "returns transaction summary with correct statistics" do
      get "/api/v1/transactions/summary", headers: auth_headers
      json = JSON.parse(response.body)
      stats = json["data"]["stats"]

      expect(response).to have_http_status(:success)
      expect(stats["total_transactions"]).to eq(2)
      expect(stats["income_total"]).to eq(1000.0)
      expect(stats["expenses_total"]).to eq(-250.0)
      expect(stats["equity_total"]).to eq(750.0)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/transactions/summary"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
