# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Savings - Update", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:saving) { create(:saving, user: user, name: "Emergency Fund", target_amount: 10000) }

  describe "PATCH /api/v1/savings/:id" do
    let(:update_params) do
      {
        saving: {
          name: "Updated Emergency Fund",
          target_amount: 15000,
          status: "paused"
        }
      }
    end

    it "updates the saving" do
      patch "/api/v1/savings/#{saving.id}", params: update_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["name"]).to eq("Updated Emergency Fund")
      expect(json["data"]["target_amount"]).to eq(15000.0)
      expect(json["data"]["status"]).to eq("paused")
      expect(json["message"]).to eq("Saving updated successfully")
    end

    it "updates associations" do
      category = create(:category, user: user)
      bank_account = create(:bank_account, user: user)

      patch "/api/v1/savings/#{saving.id}",
        params: { saving: { category_ids: [category.id], bank_account_ids: [bank_account.id] } },
        headers: auth_headers

      saving.reload
      expect(saving.categories).to include(category)
      expect(saving.bank_accounts).to include(bank_account)
    end

    it "handles validation errors" do
      patch "/api/v1/savings/#{saving.id}",
        params: { saving: { name: "AB" } }, # Too short
        headers: auth_headers

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "returns 404 for non-existent saving" do
      patch "/api/v1/savings/999999", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's saving" do
      other_user = create(:user)
      other_saving = create(:saving, user: other_user)

      patch "/api/v1/savings/#{other_saving.id}", params: update_params, headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/savings/#{saving.id}", params: update_params
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "backfill_summary" do
    let(:category) { create(:category, user: user) }
    let(:bank_account) { create(:bank_account, user: user) }

    # The mobile app reads this to toast what moved underneath the user, so the key
    # has to appear on the write that caused it — and stay absent otherwise.
    it "reports links made when the anchor moves back over an existing transaction" do
      saving.update!(opening_balance_date: Date.new(2026, 5, 19), calculation_settings: { "income" => "positive" })
      saving.category_ids = [category.id]
      saving.bank_account_ids = [bank_account.id]
      saving.update!(auto_sync_transactions: true)
      create(
        :transaction, :income, user: user, bank_account: bank_account,
        category: category, date: Date.new(2026, 5, 10), amount: 300
      )

      patch "/api/v1/savings/#{saving.id}",
        params: {
          saving: {
            opening_balance_date: "2026-05-01",
            category_ids: [category.id], bank_account_ids: [bank_account.id]
          }
        }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]["backfill_summary"]).to eq("linked" => 1, "unlinked" => 0, "skipped" => false)
    end

    it "is absent when the write changed nothing about eligibility" do
      patch "/api/v1/savings/#{saving.id}",
        params: { saving: { name: "Renamed" } }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(json["data"]).not_to have_key("backfill_summary")
    end
  end
end
