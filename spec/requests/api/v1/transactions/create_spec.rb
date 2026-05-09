# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Create", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "POST /api/v1/transactions" do
    let(:valid_params) do
      {
        transaction: {
          bank_account_id: bank_account.id,
          date: Date.current.to_s,
          description: "Test transaction",
          amount: 100.50,
          transaction_type: "income",
          category_id: category.id
        }
      }
    end

    it "creates a new transaction successfully" do
      expect {
        post "/api/v1/transactions", params: valid_params, headers: auth_headers, as: :json
      }.to change(Transaction, :count).by(1)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["amount"]).to eq(100.50)
      expect(json["data"]["source"]).to eq("manual")
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/transactions", params: { transaction: { description: "ab" } }, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/transactions", params: { transaction: {} }
      expect(response).to have_http_status(:unauthorized)
    end

    context "when user email is not confirmed" do
      let(:unconfirmed_user) { create(:user) }
      let(:unconfirmed_headers) do
        { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(unconfirmed_user).payload[:access_token]}" }
      end

      it "returns 403 EMAIL_NOT_CONFIRMED" do
        post "/api/v1/transactions", params: valid_params, headers: unconfirmed_headers, as: :json
        json = JSON.parse(response.body)

        expect(response).to have_http_status(:forbidden)
        expect(json["error"]["code"]).to eq("EMAIL_NOT_CONFIRMED")
      end
    end
  end
end
