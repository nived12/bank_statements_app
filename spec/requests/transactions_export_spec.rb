require "rails_helper"

RSpec.describe "Transactions Export", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before { sign_in_user(user) }

  describe "GET /transactions/export" do
    it "returns a CSV file" do
      create(:transaction, user: user, bank_account: bank_account, category: category)

      get "/transactions/export"

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("txns_")
      expect(response.headers["Content-Disposition"]).to include(".csv")
    end

    it "includes all filtered transactions" do
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "income", description: "Salary"
      )
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "fixed_expense", description: "Rent"
      )

      get "/transactions/export"

      csv = CSV.parse(response.body)
      expect(csv.size).to eq(3) # header + 2 rows
    end

    it "respects transaction_type filter" do
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "income", description: "Salary"
      )
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "fixed_expense", description: "Rent"
      )

      get "/transactions/export", params: { transaction_type: "income" }

      csv = CSV.parse(response.body)
      expect(csv.size).to eq(2) # header + 1 row
      expect(csv.last).to include("Salary")
    end

    it "respects date range filter" do
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        date: Date.new(2024, 1, 15), description: "Old payment from January"
      )
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        date: Date.new(2024, 12, 15), description: "Recent payment from December"
      )

      get "/transactions/export", params: { from_date: "2024-06-01" }

      csv = CSV.parse(response.body)
      expect(csv.size).to eq(2) # header + 1 row
      expect(csv.last).to include("Recent payment from December")
    end

    it "respects bank_account filter" do
      other_account = create(:bank_account, user: user)
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        description: "Account1"
      )
      create(
        :transaction, user: user, bank_account: other_account, category: category,
        description: "Account2"
      )

      get "/transactions/export", params: { bank_account_id: bank_account.id }

      csv = CSV.parse(response.body)
      expect(csv.size).to eq(2) # header + 1 row
      expect(csv.last).to include("Account1")
    end

    it "returns CSV with correct headers" do
      create(:transaction, user: user, bank_account: bank_account, category: category)

      get "/transactions/export"

      csv = CSV.parse(response.body)
      headers = csv.first

      expect(headers).to include(
        I18n.t("table_headers.date"),
        I18n.t("transactions.bank_name"),
        I18n.t("table_headers.account"),
        I18n.t("table_headers.description"),
        I18n.t("table_headers.amount"),
        I18n.t("table_headers.transaction_type"),
        I18n.t("transactions.category")
      )
    end

    it "handles empty results" do
      get "/transactions/export"

      csv = CSV.parse(response.body)
      expect(csv.size).to eq(1) # header only
    end
  end
end
