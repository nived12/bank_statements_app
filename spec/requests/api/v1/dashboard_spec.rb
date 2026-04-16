# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Dashboard", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:access_token) { Auth::GenerateTokensService.call(user).payload[:access_token] }
  let(:auth_headers) { { "Authorization" => "Bearer #{access_token}" } }

  describe "GET /api/v1/dashboard" do
    context "when authenticated" do
      let!(:bank) { create(:bank, name: "Test Bank") }
      let!(:bank_account) { create(:bank_account, user: user, bank: bank, opening_balance: 1000) }
      let!(:category) { create(:category, user: user, name: "Food", icon: "utensils") }
      let!(:transaction1) do
        create(
          :transaction, user: user, bank_account: bank_account, category: category, amount: -50,
          transaction_type: "variable_expense", date: Date.current
        )
      end
      let!(:transaction2) do
        create(
          :transaction, user: user, bank_account: bank_account, category: category, amount: 100,
          transaction_type: "income", date: Date.current
        )
      end

      it "returns dashboard data successfully" do
        get "/api/v1/dashboard", headers: auth_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        # Check data structure
        expect(json["data"]).to be_present
        expect(json["data"]["summary"]).to be_present
        expect(json["data"]["monthly_summary"]).to be_present
        expect(json["data"]["monthly_stats"]).to be_present
        expect(json["data"]["bank_accounts"]).to be_an(Array)
        expect(json["data"]["bank_summaries"]).to be_an(Array)
        expect(json["data"]["recent_transactions"]).to be_an(Array)
        expect(json["data"]["recent_statement_files"]).to be_an(Array)
        expect(json["data"]["category_summary"]).to be_present
        expect(json["data"]["spending_trends"]).to be_an(Array)
        expect(json["data"]["available_months"]).to be_an(Array)
      end

      it "includes summary statistics" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        summary = json["data"]["summary"]

        expect(summary["total_balance"]).to be_present
        expect(summary["total_transactions"]).to eq(2)
        expect(summary["total_statements"]).to eq(0)
        expect(summary["selected_month"]).to be_present
      end

      it "includes monthly summary with income and expenses" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        monthly_summary = json["data"]["monthly_summary"]

        expect(monthly_summary["total_income"]).to be_present
        expect(monthly_summary["total_expenses"]).to be_present
        expect(monthly_summary["net_income"]).to be_present
        expect(monthly_summary["income_count"]).to be >= 0
        expect(monthly_summary["expense_count"]).to be >= 0
      end

      it "includes monthly statistics" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        monthly_stats = json["data"]["monthly_stats"]

        expect(monthly_stats).to be_present
        expect(monthly_stats["average_transaction"]).to be_present
        expect(monthly_stats["largest_expense"]).to be_present
        expect(monthly_stats["largest_income"]).to be_present
        expect(monthly_stats["daily_average"]).to be_present
      end

      it "includes bank accounts with details" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        bank_accounts = json["data"]["bank_accounts"]

        expect(bank_accounts).to be_an(Array)
        expect(bank_accounts.length).to eq(1)

        account = bank_accounts.first
        expect(account["id"]).to eq(bank_account.id)
        expect(account["name"]).to be_present
        expect(account["bank_name"]).to be_present
        expect(account["account_type"]).to eq(bank_account.account_type)
        expect(account["opening_balance"]).to eq(bank_account.opening_balance.to_s)
        expect(account["balance"]).to be_present
        expect(account["currency"]).to eq(bank_account.currency)
      end

      it "includes bank summaries" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        bank_summaries = json["data"]["bank_summaries"]

        expect(bank_summaries).to be_an(Array)
        expect(bank_summaries.length).to eq(1)

        summary = bank_summaries.first
        expect(summary["account_id"]).to eq(bank_account.id)
        expect(summary["account_name"]).to be_present
        expect(summary["bank_name"]).to be_present
        expect(summary["balance"]).to be_present
        expect(summary["transaction_count"]).to eq(2)
      end

      it "includes recent transactions" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        recent_transactions = json["data"]["recent_transactions"]

        expect(recent_transactions).to be_an(Array)
        expect(recent_transactions.length).to eq(2)

        transaction = recent_transactions.first
        expect(transaction["id"]).to be_present
        expect(transaction["date"]).to be_present
        expect(transaction["description"]).to be_present
        expect(transaction["amount"]).to be_present
        expect(transaction["transaction_type"]).to be_in(
          ["income", "fixed_expense", "variable_expense", "transfer_in",
          "transfer_out"]
        )
        expect(transaction["bank_account"]).to be_present
        expect(transaction["bank_account"]["id"]).to be_present
        expect(transaction["bank_account"]["name"]).to be_present
        expect(transaction["category"]).to be_present
        expect(transaction["category"]["id"]).to be_present
        expect(transaction["category"]["name"]).to be_present
      end

      it "includes recent transactions with concept and statement_file_id fields" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        transaction = json["data"]["recent_transactions"].first
        expect(transaction).to have_key("concept")
        expect(transaction).to have_key("statement_file_id")
      end

      describe "category_summary" do
        it "includes category summary with has_data flag" do
          get "/api/v1/dashboard", headers: auth_headers

          json = JSON.parse(response.body)
          category_summary = json["data"]["category_summary"]

          expect(category_summary).to be_present
          expect(category_summary["categories"]).to be_an(Array)
          expect(category_summary).to have_key("has_data")
        end

        it "includes id, name, icon, and amount in each category entry" do
          # Expense transaction to appear in category_summary
          expense_tx = create(
            :transaction, user: user, bank_account: bank_account, category: category,
            amount: -100, transaction_type: "variable_expense", date: Date.current
          )

          get "/api/v1/dashboard", headers: auth_headers

          json = JSON.parse(response.body)
          categories = json["data"]["category_summary"]["categories"]

          if categories.any?
            cat = categories.first
            expect(cat).to have_key("id")
            expect(cat).to have_key("name")
            expect(cat).to have_key("icon")
            expect(cat).to have_key("amount")
            expect(cat["name"]).to eq("Food")
            expect(cat["icon"]).to eq("utensils")
          end
        end
      end

      it "includes available months for filtering" do
        get "/api/v1/dashboard", headers: auth_headers

        json = JSON.parse(response.body)
        available_months = json["data"]["available_months"]

        expect(available_months).to be_an(Array)
        expect(available_months).not_to be_empty

        month = available_months.first
        expect(month["value"]).to be_present
        expect(month["label"]).to be_present
      end

      it "returns empty arrays for missing data instead of nil" do
        # Create a user with no data
        empty_user = create(:user, :confirmed)
        empty_token = Auth::GenerateTokensService.call(empty_user).payload[:access_token]
        empty_headers = { "Authorization" => "Bearer #{empty_token}" }

        get "/api/v1/dashboard", headers: empty_headers

        json = JSON.parse(response.body)

        # Arrays should be empty, not nil
        expect(json["data"]["bank_accounts"]).to eq([])
        expect(json["data"]["bank_summaries"]).to eq([])
        expect(json["data"]["recent_transactions"]).to eq([])
        expect(json["data"]["recent_statement_files"]).to eq([])
        expect(json["data"]["spending_trends"]).to eq([])

        # Hashes should have default values, not be nil
        expect(json["data"]["monthly_summary"]).to be_present
        expect(json["data"]["monthly_stats"]).to be_present
        expect(json["data"]["category_summary"]).to be_present
      end

      context "with month parameter" do
        it "accepts month parameter and filters data" do
          last_month = 1.month.ago.beginning_of_month

          get "/api/v1/dashboard", params: { month: last_month.strftime("%Y-%m") }, headers: auth_headers

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json["data"]["summary"]["selected_month"]).to eq(last_month.strftime("%Y-%m"))
        end

        it "uses current month when month parameter is not provided" do
          get "/api/v1/dashboard", headers: auth_headers

          json = JSON.parse(response.body)

          expect(json["data"]["summary"]["selected_month"]).to eq(Date.current.beginning_of_month.strftime("%Y-%m"))
        end
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/dashboard"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end

    context "when token is invalid" do
      it "returns 401 unauthorized" do
        get "/api/v1/dashboard", headers: { "Authorization" => "Bearer invalid.token.here" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end
end
