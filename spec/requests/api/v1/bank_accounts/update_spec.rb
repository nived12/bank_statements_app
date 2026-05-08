# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Update", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "PATCH /api/v1/bank_accounts/:id" do
    let(:bank) { create(:bank, name: "Test Bank", code: "test") }
    let(:bank_account) { create(:bank_account, user: user, bank: bank, custom_name: "Old Name") }
    let(:update_params) do
      {
        bank_account: {
          custom_name: "New Name",
          opening_balance: 2000.00
        }
      }
    end

    it "updates bank account successfully" do
      patch "/api/v1/bank_accounts/#{bank_account.id}", params: update_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["custom_name"]).to eq("New Name")
      expect(json["data"]["opening_balance"]).to eq("2000.0")
      expect(json["message"]).to eq("Bank account updated successfully")
    end

    it "updates account_number successfully" do
      update_params = {
        bank_account: {
          account_number: "9999999999"
        }
      }

      patch "/api/v1/bank_accounts/#{bank_account.id}", params: update_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(json["data"]["account_number"]).to eq("9999999999")
    end

    it "returns validation errors for invalid update" do
      invalid_params = {
        bank_account: {
          account_number: ""
        }
      }

      patch "/api/v1/bank_accounts/#{bank_account.id}", params: invalid_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to update bank account")
    end

    it "returns 404 for non-existent bank account" do
      patch "/api/v1/bank_accounts/999999", params: update_params, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when updating another user's bank account" do
      other_user = create(:user, :consented)
      other_bank_account = create(:bank_account, user: other_user, bank: bank)

      patch "/api/v1/bank_accounts/#{other_bank_account.id}", params: update_params, headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      patch "/api/v1/bank_accounts/#{bank_account.id}", params: update_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
