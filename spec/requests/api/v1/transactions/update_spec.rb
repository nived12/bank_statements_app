# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Update", type: :request do
  let(:user) { create(:user) }
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

    it "adds items and tax/tip via nested attributes" do
      patch "/api/v1/transactions/#{transaction.id}",
        params: {
          transaction: {
            tax_amount: 8.0,
            tip_amount: 5.0,
            transaction_items_attributes: [
              { name: "Coffee", amount: 45.0, position: 0 }
            ]
          }
        },
        headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:success)
      expect(json["data"]["tax_amount"]).to eq(8.0)
      expect(json["data"]["tip_amount"]).to eq(5.0)
      expect(json["data"]["items"].length).to eq(1)
    end

    it "destroys an item via _destroy" do
      item = create(:transaction_item, transaction_record: transaction, name: "Old item", amount: 30.0)

      patch "/api/v1/transactions/#{transaction.id}",
        params: {
          transaction: {
            transaction_items_attributes: [{ id: item.id, _destroy: "1" }]
          }
        },
        headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      expect(TransactionItem.exists?(item.id)).to be false
    end

    it "updates statement file transactions" do
      statement_transaction = create(
        :transaction, user: user, bank_account: bank_account, category: category,
        source: :statement_file
      )

      patch "/api/v1/transactions/#{statement_transaction.id}",
        params: { transaction: { description: "Updated imported" } },
        headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["description"]).to eq("Updated imported")
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/transactions/#{transaction.id}", params: { transaction: {} }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
