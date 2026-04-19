# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Goals - Create", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "POST /api/v1/goals" do
    let(:valid_savings_goal_params) do
      {
        goal: {
          name: "Vacation Fund",
          goal_type: "savings_goal",
          start_date: Date.current.to_s,
          deadline: 1.year.from_now.to_date.to_s,
          color: "#3B82F6",
          icon: "🏖️",
          notes: "Summer vacation savings"
        }
      }
    end

    let(:valid_debt_payoff_params) do
      {
        goal: {
          name: "Pay Off Credit Card",
          goal_type: "debt_payoff",
          start_date: Date.current.to_s,
          deadline: 2.years.from_now.to_date.to_s,
          debt_strategy: "avalanche",
          color: "#EF4444",
          icon: "💳"
        }
      }
    end

    it "creates a savings goal" do
      expect {
        post "/api/v1/goals", params: valid_savings_goal_params, headers: auth_headers
      }.to change(Goal, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns the created savings goal" do
      post "/api/v1/goals", params: valid_savings_goal_params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(json["data"]["name"]).to eq("Vacation Fund")
      expect(json["data"]["goal_type"]).to eq("savings_goal")
      expect(json["data"]["status"]).to eq("active")
      expect(json["message"]).to eq("Goal created successfully")
    end

    it "creates a debt payoff goal" do
      expect {
        post "/api/v1/goals", params: valid_debt_payoff_params, headers: auth_headers
      }.to change(Goal, :count).by(1)

      json = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(json["data"]["goal_type"]).to eq("debt_payoff")
      expect(json["data"]["debt_strategy"]).to eq("avalanche")
    end

    it "associates savings via saving_ids" do
      saving = create(:saving, user: user)
      params = valid_savings_goal_params.deep_dup
      params[:goal][:saving_ids] = [saving.id]

      post "/api/v1/goals", params: params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:created)
      expect(json["data"]["savings"].length).to eq(1)
      expect(json["data"]["savings"][0]["id"]).to eq(saving.id)
    end

    it "associates debts via debt_ids" do
      debt = create(:debt, user: user)
      params = valid_debt_payoff_params.deep_dup
      params[:goal][:debt_ids] = [debt.id]

      post "/api/v1/goals", params: params, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:created)
      expect(json["data"]["debts"].length).to eq(1)
      expect(json["data"]["debts"][0]["id"]).to eq(debt.id)
    end

    it "handles validation errors for missing name" do
      post "/api/v1/goals", params: { goal: { name: "AB", goal_type: "savings_goal" } }, headers: auth_headers
      json = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      expect(json["error"]["message"]).to eq("Failed to create goal")
      expect(json["error"]["details"]).to be_an(Array)
    end

    it "handles validation errors for missing debt_strategy on debt_payoff" do
      params = { goal: { name: "Pay Off Loan", goal_type: "debt_payoff", start_date: Date.current.to_s, deadline: 1.year.from_now.to_date.to_s } }
      post "/api/v1/goals", params: params, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
    end

    it "returns 401 when not authenticated" do
      post "/api/v1/goals", params: valid_savings_goal_params
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
