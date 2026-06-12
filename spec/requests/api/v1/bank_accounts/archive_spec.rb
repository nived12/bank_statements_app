# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Archive/Unarchive", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank", code: "test") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }

  describe "PATCH /api/v1/bank_accounts/:id/archive" do
    it "archives the bank account" do
      patch "/api/v1/bank_accounts/#{bank_account.id}/archive", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["archived"]).to be true
      expect(json["data"]["archived_at"]).to be_present
      expect(bank_account.reload).to be_discarded
    end

    it "returns 404 for another user's bank account" do
      other_user = create(:user)
      other_account = create(:bank_account, user: other_user, bank: bank)

      patch "/api/v1/bank_accounts/#{other_account.id}/archive", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent bank account" do
      patch "/api/v1/bank_accounts/999999/archive", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/bank_accounts/#{bank_account.id}/archive"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/bank_accounts/:id/unarchive" do
    let!(:archived_account) { create(:bank_account, user: user, bank: bank, discarded_at: Time.current) }

    it "unarchives the bank account" do
      patch "/api/v1/bank_accounts/#{archived_account.id}/unarchive", headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["archived"]).to be false
      expect(json["data"]["archived_at"]).to be_nil
      expect(archived_account.reload).to be_undiscarded
    end

    it "returns 404 for another user's bank account" do
      other_user = create(:user)
      other_account = create(:bank_account, user: other_user, bank: bank, discarded_at: Time.current)

      patch "/api/v1/bank_accounts/#{other_account.id}/unarchive", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/bank_accounts/#{archived_account.id}/unarchive"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/bank_accounts - archived filtering" do
    let!(:kept_account) { create(:bank_account, user: user, bank: bank, custom_name: "Active") }
    let!(:discarded_account) { create(:bank_account, user: user, bank: bank, custom_name: "Archived", discarded_at: Time.current) }

    it "excludes archived accounts by default" do
      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      ids = json["data"]["bank_accounts"].map { |a| a["id"] }
      expect(ids).to include(kept_account.id)
      expect(ids).not_to include(discarded_account.id)
    end

    it "returns only archived accounts with ?archived=true" do
      get "/api/v1/bank_accounts", params: { archived: true }, headers: auth_headers
      json = JSON.parse(response.body)

      ids = json["data"]["bank_accounts"].map { |a| a["id"] }
      expect(ids).not_to include(kept_account.id)
      expect(ids).to include(discarded_account.id)
    end

    it "includes archived field in response" do
      get "/api/v1/bank_accounts", headers: auth_headers
      json = JSON.parse(response.body)

      account = json["data"]["bank_accounts"].find { |a| a["id"] == kept_account.id }
      expect(account).to have_key("archived")
      expect(account["archived"]).to be false
    end
  end
end
