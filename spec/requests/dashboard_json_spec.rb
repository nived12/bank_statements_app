require "rails_helper"

RSpec.describe "Dashboard JSON API", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /dashboard.json" do
    before do
      sign_in_user_with_locale(user)
    end

    context "with financial data" do
      let(:current_month) { Date.current.beginning_of_month }

      before do
        create(:transaction, user: user, bank_account: bank_account,
               date: current_month + 10.days, amount: 5000, transaction_type: 'income')
        create(:transaction, user: user, bank_account: bank_account,
               date: current_month + 15.days, amount: -1500, transaction_type: 'variable_expense', category: category)
      end

      it "returns successful response" do
        get "/es/dashboard.json"

        expect(response).to have_http_status(:success)
      end

      it "returns dashboard data structure" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)

        expect(json).to have_key("dashboard")
        expect(json["dashboard"]).to have_key("selected_month")
        expect(json["dashboard"]).to have_key("available_months")
        expect(json["dashboard"]).to have_key("widgets")
        expect(json["dashboard"]).to have_key("data")
      end

      it "includes widget configuration" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        widgets = json.dig("dashboard", "widgets")

        expect(widgets).to be_an(Array)
        expect(widgets.any? { |w| w["id"] == "financial_health" }).to be true
      end

      it "includes monthly summary data" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        summary = json.dig("dashboard", "data", "monthly_summary")

        expect(summary).to be_present
        expect(summary).to have_key("income")
        expect(summary).to have_key("expenses")
        expect(summary).to have_key("net")
        expect(summary).to have_key("count")
        expect(summary).to have_key("has_data")
        expect(summary["has_data"]).to be true
      end

      it "includes bank account information" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        accounts = json.dig("dashboard", "data", "bank_accounts")

        expect(accounts).to be_an(Array)
        expect(accounts.length).to eq(1)
        expect(accounts.first).to have_key("id")
        expect(accounts.first).to have_key("bank_name")
        expect(accounts.first["bank_name"]).to include("bbva")
      end

      it "includes recent transactions" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        transactions = json.dig("dashboard", "data", "recent_transactions")

        expect(transactions).to be_an(Array)
        expect(transactions.length).to be > 0
        expect(transactions.first).to have_key("id")
        expect(transactions.first).to have_key("description")
        expect(transactions.first).to have_key("amount")
        expect(transactions.first).to have_key("date")
      end

      it "includes totals" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        data = json.dig("dashboard", "data")

        expect(data).to have_key("total_balance")
        expect(data).to have_key("total_transactions")
        expect(data).to have_key("total_statements")
        expect(data["total_transactions"]).to eq(2)
      end
    end

    context "with no data" do
      it "returns empty state data" do
        get "/es/dashboard.json"

        json = JSON.parse(response.body)
        summary = json.dig("dashboard", "data", "monthly_summary")

        expect(summary["has_data"]).to be false
        expect(summary["income"].to_f).to eq(0)
        expect(summary["expenses"].to_f).to eq(0)
      end
    end
  end
end
