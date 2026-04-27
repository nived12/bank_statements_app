# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Savings - Create", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, user: user) }
  let(:bank_account) { create(:bank_account, user: user) }

  describe "POST /api/v1/savings" do
    let(:valid_params) do
      {
        saving: {
          name: "Emergency Fund",
          target_amount: 10000,
          current_amount: 2500,
          target_date: 1.year.from_now.to_date,
          color: "#FF5733",
          icon: "💰",
          status: "active",
          notes: "For emergencies",
          contribution_mode: "fixed",
          contribution_frequency: "monthly",
          target_contribution_amount: 500,
          category_ids: [category.id],
          bank_account_ids: [bank_account.id]
        }
      }
    end

    it "creates a new saving" do
      expect {
        post "/api/v1/savings", params: valid_params, headers: auth_headers
      }.to change(Saving, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns the created saving" do
      post "/api/v1/savings", params: valid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["name"]).to eq("Emergency Fund")
      expect(json["data"]["target_amount"]).to eq(10000.0)
      expect(json["data"]["current_amount"]).to eq(2500.0)
      expect(json["data"]["status"]).to eq("active")
      expect(json["data"]["color"]).to eq("#FF5733")
      expect(json["message"]).to eq("Saving created successfully")
    end

    it "associates categories and bank accounts" do
      post "/api/v1/savings", params: valid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["categories"].length).to eq(1)
      expect(json["data"]["categories"][0]["id"]).to eq(category.id)
      expect(json["data"]["bank_accounts"].length).to eq(1)
      expect(json["data"]["bank_accounts"][0]["id"]).to eq(bank_account.id)
    end

    it "handles validation errors" do
      invalid_params = { saving: { name: "AB" } } # Name too short

      post "/api/v1/savings", params: invalid_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to create saving")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "sanitizes money fields (removes commas)" do
      params_with_commas = valid_params.deep_dup
      params_with_commas[:saving][:target_amount] = "10,000"
      params_with_commas[:saving][:current_amount] = "2,500"

      post "/api/v1/savings", params: params_with_commas, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["target_amount"]).to eq(10000.0)
      expect(json["data"]["current_amount"]).to eq(2500.0)
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/savings", params: valid_params
      expect(response).to have_http_status(:unauthorized)
    end

    context "when user email is not confirmed" do
      let(:unconfirmed_headers) do
        u = create(:user)
        { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(u).payload[:access_token]}" }
      end

      it "returns 403 EMAIL_NOT_CONFIRMED" do
        post "/api/v1/savings", params: valid_params, headers: unconfirmed_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("EMAIL_NOT_CONFIRMED")
      end
    end
  end
end
