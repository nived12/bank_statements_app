# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Debts - Update", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:debt) { create(:debt, user: user, name: "Credit Card", original_amount: 5000) }

  describe "PATCH /api/v1/debts/:id" do
    let(:update_params) do
      {
        debt: {
          name: "Updated Credit Card",
          opening_balance: 2000,
          status: "paused"
        }
      }
    end

    it "updates the debt" do
      patch "/api/v1/debts/#{debt.id}", params: update_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["name"]).to eq("Updated Credit Card")
      expect(json["data"]["opening_balance"]).to eq(2000.0)
      expect(json["data"]["current_balance"]).to eq(2000.0)
      expect(json["data"]["status"]).to eq("paused")
      expect(json["message"]).to eq("Debt updated successfully")
    end

    it "updates associations" do
      category = create(:category, user: user)
      bank_account = create(:bank_account, user: user)

      patch "/api/v1/debts/#{debt.id}",
        params: { debt: { category_ids: [category.id], bank_account_ids: [bank_account.id] } },
        headers: auth_headers

      debt.reload
      expect(debt.categories).to include(category)
      expect(debt.bank_accounts).to include(bank_account)
    end

    it "handles validation errors" do
      patch "/api/v1/debts/#{debt.id}",
        params: { debt: { name: "AB" } }, # Too short
        headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "returns 404 for non-existent debt" do
      patch "/api/v1/debts/999999", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's debt" do
      other_user = create(:user)
      other_debt = create(:debt, user: other_user)

      patch "/api/v1/debts/#{other_debt.id}", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/debts/#{debt.id}", params: update_params
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "backfill_summary" do
    let(:category) { create(:category, user: user) }
    let(:bank_account) { create(:bank_account, user: user) }

    # The mobile app reads this to toast what moved underneath the user, so the key
    # has to appear on the write that caused it — and stay absent otherwise.
    it "reports links made when the anchor moves back over an existing transaction" do
      debt.update!(opening_balance_date: Date.new(2026, 5, 19), calculation_settings: { "expense" => "positive" })
      debt.category_ids = [category.id]
      debt.bank_account_ids = [bank_account.id]
      debt.update!(auto_sync_transactions: true)
      create(
        :transaction, :variable_expense, user: user, bank_account: bank_account,
        category: category, date: Date.new(2026, 5, 10), amount: -300
      )

      patch "/api/v1/debts/#{debt.id}",
        params: {
          debt: {
            opening_balance_date: "2026-05-01",
            category_ids: [category.id], bank_account_ids: [bank_account.id]
          }
        }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["backfill_summary"]).to eq("linked" => 1, "unlinked" => 0, "skipped" => false)
    end

    it "is absent when the write changed nothing about eligibility" do
      patch "/api/v1/debts/#{debt.id}",
        params: { debt: { name: "Renamed" } }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]).not_to have_key("backfill_summary")
    end
  end
end
