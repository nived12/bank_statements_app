# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Recurring", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let!(:bank_account) { create(:bank_account, user: user) }

  describe "GET /api/v1/recurring" do
    let!(:active)    { create(:recurring_series, user: user, name: "Netflix", next_due_date: Date.current + 3) }
    let!(:detected)  do
      create(:recurring_series, :detected, user: user, name: "Detected One", description_signature: "detected-one")
    end
    let!(:cancelled) { create(:recurring_series, :cancelled, user: user, description_signature: "cancelled-one") }

    it "returns all series + summary" do
      get "/api/v1/recurring", headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["series"].size).to eq(3)
      expect(body["data"]["summary"]).to include(
        "monthly_total", "annual_total", "active_count", "detected_count",
        "upcoming"
      )
      expect(body["data"]["summary"]["active_count"]).to eq(1)
      expect(body["data"]["summary"]["detected_count"]).to eq(1)
      expect(body["data"]["summary"]["upcoming"].size).to eq(1)
    end

    it "filters by status" do
      get "/api/v1/recurring", params: { status: "detected" }, headers: auth_headers
      body = JSON.parse(response.body)
      expect(body["data"]["series"].size).to eq(1)
      expect(body["data"]["series"].first["name"]).to eq("Detected One")
    end
  end

  describe "POST /api/v1/recurring" do
    it "creates a manual series" do
      payload = {
        recurring_series: {
          name: "Spotify",
          expected_amount: 199.00,
          frequency: "monthly",
          next_due_date: (Date.current + 5).to_s,
          transaction_type: "fixed_expense"
        }
      }
      expect {
        post "/api/v1/recurring", params: payload, headers: auth_headers
      }.to change { user.recurring_series.count }.by(1)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["data"]["source"]).to eq("manual")
    end

    it "returns 422 on invalid payload" do
      post "/api/v1/recurring",
        params: { recurring_series: { name: "", expected_amount: -1, frequency: "weekly",
next_due_date: Date.current, transaction_type: "fixed_expense" } },
        headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/recurring/:id" do
    let!(:series) { create(:recurring_series, user: user) }

    it "updates fields including status (pause)" do
      patch "/api/v1/recurring/#{series.id}",
        params: { recurring_series: { status: "paused" } },
        headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(series.reload.status).to eq("paused")
    end

    it "promotes a detected series via status: active" do
      detected = create(:recurring_series, :detected, user: user, description_signature: "spotify-detected")
      patch "/api/v1/recurring/#{detected.id}",
        params: { recurring_series: { status: "active" } },
        headers: auth_headers
      expect(detected.reload.status).to eq("active")
    end
  end

  describe "DELETE /api/v1/recurring/:id" do
    let!(:series) { create(:recurring_series, user: user) }

    it "destroys and returns 204" do
      delete "/api/v1/recurring/#{series.id}", headers: auth_headers
      expect(response).to have_http_status(:no_content)
      expect(RecurringSeries.exists?(series.id)).to be(false)
    end
  end

  describe "POST /api/v1/recurring/:id/process_due" do
    let!(:series) { create(:recurring_series, user: user, next_due_date: Date.current) }

    it "confirm: creates transaction and advances next_due_date" do
      expect {
        post "/api/v1/recurring/#{series.id}/process_due",
          params: { action_type: "confirm" },
          headers: auth_headers
      }.to change { Transaction.count }.by(1)
      expect(response).to have_http_status(:ok)
      expect(series.reload.next_due_date).to eq(Date.current + 30)
    end

    it "skip: advances without creating transaction" do
      expect {
        post "/api/v1/recurring/#{series.id}/process_due",
          params: { action_type: "skip" },
          headers: auth_headers
      }.not_to change { Transaction.count }
      expect(series.reload.next_due_date).to eq(Date.current + 30)
    end

    it "rejects invalid action_type" do
      post "/api/v1/recurring/#{series.id}/process_due",
        params: { action_type: "bogus" },
        headers: auth_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/recurring/scan" do
    before do
      5.times do |i|
        create(
          :transaction,
          user: user, bank_account: bank_account,
          description: "NETFLIX.COM",
          amount: -219.00,
          transaction_type: "fixed_expense",
          date: Date.current - (5 - i) * 30,
          statement_file: nil, category: nil
        )
      end
    end

    it "runs detection and returns detected series" do
      post "/api/v1/recurring/scan", headers: auth_headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["detected"].size).to eq(1)
    end
  end

  describe "subscription gate" do
    it "returns 402 when trial has expired and user has no paid subscription" do
      user.update!(trial_ends_at: 1.day.ago)
      get "/api/v1/recurring", headers: auth_headers
      expect(response).to have_http_status(:payment_required)
    end
  end
end
