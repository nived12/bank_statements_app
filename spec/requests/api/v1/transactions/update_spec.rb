# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Update", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "PATCH /api/v1/transactions/:id" do
    let(:transaction) do
      create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual, amount: 50.0)
    end

    it "updates transaction successfully" do
      patch "/api/v1/transactions/#{transaction.id}",
        params: { transaction: { description: "Updated", amount: 75.0 } },
        headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["description"]).to eq("Updated")
      expect(json["data"]["amount"]).to eq(-75.0)
    end

    it "prevents updating statement file transactions" do
      statement_transaction = create(
        :transaction, user: user, bank_account: bank_account, category: category,
        source: :statement_file
      )

      patch "/api/v1/transactions/#{statement_transaction.id}",
        params: { transaction: { description: "New" } },
        headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("UPDATE_NOT_ALLOWED")
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: {} }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
