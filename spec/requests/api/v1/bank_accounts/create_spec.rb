# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts - Create", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "POST /api/v1/bank_accounts" do
    let(:bank) { create(:bank, name: "Test Bank", code: "test") }
    let(:valid_params) do
      {
        bank_account: {
          bank_id: bank.id,
          account_number: "1234567890",
          custom_name: "My Savings",
          currency: "MXN",
          opening_balance: 1000.50,
          opening_balance_date: "2024-01-01",
          account_type: "debit"
        }
      }
    end

    it "creates a new bank account successfully" do
      initial_count = user.bank_accounts.count

      post "/api/v1/bank_accounts", params: valid_params, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["account_number"]).to eq("1234567890")
      expect(json["data"]["custom_name"]).to eq("My Savings")
      expect(json["data"]["currency"]).to eq("MXN")
      expect(json["data"]["opening_balance"]).to eq("1000.5")
      expect(json["data"]["account_type"]).to eq("debit")
      expect(json["message"]).to eq("Bank account created successfully")
      expect(user.bank_accounts.count).to eq(initial_count + 1)
    end

    it "creates a bank account without custom_name" do
      params_without_name = valid_params.deep_dup
      params_without_name[:bank_account].delete(:custom_name)

      post "/api/v1/bank_accounts", params: params_without_name, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["custom_name"]).to be_nil
    end

    it "returns validation errors for missing required fields" do
      invalid_params = {
        bank_account: {
          account_number: "1234567890"
        }
      }

      post "/api/v1/bank_accounts", params: invalid_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to create bank account")
      expect(json["error"]["details"]).to be_present
    end

    it "returns validation errors for blank account_number" do
      invalid_params = {
        bank_account: {
          bank_id: bank.id,
          account_number: "",
          opening_balance_date: "2024-01-01"
        }
      }

      post "/api/v1/bank_accounts", params: invalid_params, headers: auth_headers, as: :json
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/bank_accounts", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context "when user email is not confirmed" do
      let(:unconfirmed_headers) do
        u = create(:user)
        { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(u).payload[:access_token]}" }
      end

      it "returns 403 EMAIL_NOT_CONFIRMED" do
        post "/api/v1/bank_accounts", params: valid_params, headers: unconfirmed_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("EMAIL_NOT_CONFIRMED")
      end
    end
  end
end
