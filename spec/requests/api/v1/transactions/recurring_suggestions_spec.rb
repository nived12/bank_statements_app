# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Recurring Suggestions", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, name: "Streaming", user: user) }

  describe "GET /api/v1/transactions/recurring_suggestions" do
    context "with qualifying recurring patterns" do
      before do
        # Netflix: 3 transactions in last 60 days (~monthly)
        [60, 30, 5].each do |days_ago|
          create(
            :transaction,
            user: user,
            bank_account: bank_account,
            merchant: "Netflix",
            amount: -199.0,
            transaction_type: "variable_expense",
            date: days_ago.days.ago.to_date,
            category: category
          )
        end

        # Single "Random" transaction — should be excluded (< 2 occurrences)
        create(
          :transaction,
          user: user,
          bank_account: bank_account,
          merchant: "Random Store",
          amount: -50.0,
          transaction_type: "variable_expense",
          date: 10.days.ago.to_date
        )
      end

      it "returns merchants with 2+ occurrences" do
        get "/api/v1/transactions/recurring_suggestions",
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        merchants = json["data"].map { |r| r["merchant"].downcase }
        expect(merchants).to include("netflix")
        expect(merchants).not_to include("random store")
      end

      it "returns correct shape for each suggestion" do
        get "/api/v1/transactions/recurring_suggestions",
          headers: auth_headers

        json = JSON.parse(response.body)
        netflix = json["data"].find { |r| r["merchant"].downcase == "netflix" }

        expect(netflix["amount"]).to be_a(Float)
        expect(netflix["frequency_days"]).to be_a(Integer)
        expect(netflix["last_seen"]).to match(/\d{4}-\d{2}-\d{2}/)
        expect(netflix).to have_key("suggested_category_id")
      end
    end

    context "with no qualifying transactions" do
      it "returns empty data array" do
        get "/api/v1/transactions/recurring_suggestions",
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end

    context "with transactions older than 90 days" do
      before do
        # 2 Netflix transactions but both older than 90 days — should be excluded
        [100, 130].each do |days_ago|
          create(
            :transaction,
            user: user,
            bank_account: bank_account,
            merchant: "Netflix",
            amount: -199.0,
            transaction_type: "variable_expense",
            date: days_ago.days.ago.to_date
          )
        end
      end

      it "excludes transactions outside the 90-day window" do
        get "/api/v1/transactions/recurring_suggestions",
          headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]).to eq([])
      end
    end

    context "when not authenticated" do
      it "returns 401" do
        get "/api/v1/transactions/recurring_suggestions"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
