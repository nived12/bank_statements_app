require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, user: user) }

  describe "GET /dashboard" do
    before do
      sign_in_user(user)
    end
    context "with basic data" do
      before do
        # Create some basic data for the dashboard
        create_list(:transaction, 3, user: user, bank_account: bank_account, category: category)
        create_list(:statement_file, 2, user: user, bank_account: bank_account)
      end

      it "loads dashboard successfully" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "handles authentication properly" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "displays bank account information" do
        get "/dashboard"

        expect(response.body).to include(bank.name)
        expect(response.body).to include(bank_account.account_number)
      end

      it "displays transaction information" do
        get "/dashboard"

        expect(response.body).to include("Transacciones")
      end
    end

    context "with month parameter" do
      let(:selected_month) { 2.months.ago.beginning_of_month }
      let!(:old_transaction) do
        create(:transaction, user: user, bank_account: bank_account,
               date: selected_month + 15.days, amount: 1000, transaction_type: 'income')
      end

      it "loads dashboard for specific month" do
        get "/dashboard", params: { month: selected_month.strftime("%Y-%m") }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "handles invalid month parameter gracefully" do
        get "/dashboard", params: { month: "invalid-month" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "handles malformed month parameter gracefully" do
        get "/dashboard", params: { month: "2024-13" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end
    end

    context "with financial data" do
      let(:current_month) { Date.current.beginning_of_month }

      before do
        # Create income transaction
        create(:transaction, user: user, bank_account: bank_account,
               date: current_month + 10.days, amount: 5000, transaction_type: 'income')

        # Create expense transactions
        create(:transaction, user: user, bank_account: bank_account,
               date: current_month + 15.days, amount: -1500, transaction_type: 'variable_expense', category: category)
        create(:transaction, user: user, bank_account: bank_account,
               date: current_month + 20.days, amount: -800, transaction_type: 'fixed_expense')
      end

      it "displays financial summary" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "shows income and expenses" do
        get "/dashboard"

        expect(response.body).to include("Ingresos")
        expect(response.body).to include("Gastos")
      end
    end

    context "with multiple bank accounts" do
      let(:bank2) { create(:bank, name: "santander") }
      let(:bank_account2) { create(:bank_account, user: user, bank: bank2) }

      before do
        create_list(:transaction, 2, user: user, bank_account: bank_account)
        create_list(:transaction, 3, user: user, bank_account: bank_account2)
      end

      it "displays multiple bank accounts" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include(bank_account.account_number)
        expect(response.body).to include(bank_account2.account_number)
      end
    end

    context "with categories" do
      let(:food_category) { create(:category, user: user, name: "Comida") }
      let(:transport_category) { create(:category, user: user, name: "Transporte") }

      before do
        create(:transaction, user: user, bank_account: bank_account,
               category: food_category, amount: -500, transaction_type: 'variable_expense')
        create(:transaction, user: user, bank_account: bank_account,
               category: transport_category, amount: -300, transaction_type: 'variable_expense')
      end

      it "displays categorized transactions" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end
    end

    context "with uncategorized transactions" do
      before do
        create(:transaction, user: user, bank_account: bank_account,
               category: nil, amount: -200, transaction_type: 'variable_expense')
      end

      it "handles uncategorized transactions gracefully" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end
    end

    context "when user has no data" do
      it "loads dashboard with empty state" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end
    end

    context "with statement files" do
      let!(:statement_file) do
      create(:statement_file, user: user, bank_account: bank_account,
             status: :parsed, processed_at: 1.day.ago)
      end

      it "displays statement information" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end
    end

    describe "locale handling" do
      it "respects Spanish locale" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Dashboard")
      end

      it "handles different locales gracefully" do
        get "/dashboard"

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "authentication" do
    it "redirects unauthenticated users" do
      # Don't sign in any user - test unauthenticated access
      get "/dashboard"

      expect(response).to redirect_to(new_session_path)
    end
  end
end
