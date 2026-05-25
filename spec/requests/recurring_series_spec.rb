# frozen_string_literal: true

require "rails_helper"

RSpec.describe "RecurringSeries", type: :request do
  let(:user) { create(:user) }
  let!(:bank_account) { create(:bank_account, user: user) }

  describe "GET /recurring (unauthenticated)" do
    it "redirects to sign in" do
      get "/recurring"
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /recurring (authenticated)" do
    before { sign_in_user(user) }

    it "renders the index" do
      create(:recurring_series, user: user, name: "Netflix")
      get "/recurring"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Netflix")
    end

    it "redirects to /pricing when subscription gate denies" do
      user.update!(trial_ends_at: 1.day.ago)
      get "/recurring"
      expect(response).to redirect_to(pricing_path)
    end
  end

  describe "POST /recurring/:id/process_due" do
    let!(:series) { create(:recurring_series, user: user, next_due_date: Date.current) }

    before { sign_in_user(user) }

    it "confirm: creates a transaction and advances next_due_date" do
      expect {
        post "/recurring/#{series.id}/process_due", params: { action_type: "confirm" }
      }.to change { Transaction.count }.by(1)
      expect(response).to redirect_to(recurring_series_index_path)
      expect(flash[:notice]).to be_present
      expect(series.reload.next_due_date).to eq(Date.current + 30)
    end

    it "skip: advances without creating transaction" do
      expect {
        post "/recurring/#{series.id}/process_due", params: { action_type: "skip" }
      }.not_to change { Transaction.count }
      expect(series.reload.next_due_date).to eq(Date.current + 30)
    end

    it "shows a flash alert when the user has no bank accounts" do
      bank_account.destroy!
      post "/recurring/#{series.id}/process_due", params: { action_type: "confirm" }
      expect(response).to redirect_to(recurring_series_index_path)
      expect(flash[:alert]).to eq(I18n.t("recurring.errors.no_bank_account"))
      expect(Transaction.where(recurring_series_id: series.id).count).to eq(0)
      expect(series.reload.next_due_date).to eq(Date.current)
    end

    it "passes amount and date through to the processor" do
      post "/recurring/#{series.id}/process_due",
        params: { action_type: "confirm", amount: "-99.99", date: (Date.current - 2).to_s }
      txn = Transaction.where(recurring_series_id: series.id).last
      expect(txn.amount).to eq(-99.99)
      expect(txn.date).to eq(Date.current - 2)
    end
  end

  describe "restore flow (cancelled → active)" do
    let!(:series) { create(:recurring_series, user: user, status: "cancelled") }

    before { sign_in_user(user) }

    it "reactivates a cancelled series and clears cancelled_at" do
      expect(series.cancelled_at).to be_present
      patch "/recurring/#{series.id}", params: { recurring_series: { status: "active" } }
      expect(series.reload.status).to eq("active")
      expect(series.cancelled_at).to be_nil
    end
  end
end
