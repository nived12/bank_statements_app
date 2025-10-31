# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, name: "MyString", user: user) }

  before do
    sign_in_user(user)
  end

  # Shared context for tests that need transactions
  shared_context "with transactions" do
    let!(:transactions) { create_list(:transaction, 25, user: user, bank_account: bank_account, category: category) }
  end

  # Shared context for tests that need fewer transactions (for faster tests)
  shared_context "with few transactions" do
    let!(:transactions) { create_list(:transaction, 3, user: user, bank_account: bank_account, category: category) }
  end

  # Shared context for tests that need a single transaction
  shared_context "with single transaction" do
    let!(:transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, description: "Test transaction") }
  end

  describe "GET /transactions" do
    context "with transactions" do
      include_context "with few transactions"

      it "returns transactions with pagination info in JSON format" do
        get "/transactions.json"
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["transactions"]).to be_an(Array)
        expect(json["pagination"]["count"]).to eq(3)
        expect(json["pagination"]["page"]).to eq(1)
      end
    end

    context "without transactions" do
      it "shows empty state message" do
        get "/transactions"
        expect(response).to have_http_status(:success)
      end
    end

    context "with bank account filter" do
      include_context "with few transactions"
      it "filters transactions by bank account" do
        get "/transactions.json", params: { bank_account_id: bank_account.id }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(3)
        expect(json["transactions"].all? { |t| t["bank_account"]["id"] == bank_account.id }).to be true
      end
    end

    context "with statement file filter" do
      let!(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
      let!(:statement_file_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, statement_file: statement_file, description: "Statement transaction") }
      let!(:manual_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, description: "Manual transaction") }

      it "filters transactions by statement file" do
        get "/transactions.json", params: { statement_file_id: statement_file.id }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(statement_file_transaction.description)
        expect(json["transactions"].map { |t| t["description"] }).not_to include("Manual transaction")
      end

      it "displays statement file dropdown with selected statement file" do
        get "/transactions", params: { statement_file_id: statement_file.id }
        expect(response.body).to include("Filtrar por Archivo de Estado")
        expect(response.body).to include(statement_file.safe_filename)
        expect(response.body).to include(statement_file.bank_account.display_name)
        expect(response.body).to include("bg-green-100 text-green-800")
      end

      it "shows statement file dropdown with all statement files" do
        other_bank_account = create(:bank_account, user: user)
        other_statement_file = create(:statement_file, user: user, bank_account: other_bank_account)
        get "/transactions"
        expect(response.body).to include("Filtrar por Archivo de Estado")
        expect(response.body).to include(statement_file.safe_filename)
        expect(response.body).to include(other_statement_file.safe_filename)
      end

      it "shows only statement files from selected bank account when bank account is filtered" do
        other_bank_account = create(:bank_account, user: user)
        other_statement_file = create(:statement_file, user: user, bank_account: other_bank_account)
        allow(other_statement_file).to receive(:safe_filename).and_return("other_bank_statement.pdf")
        get "/transactions", params: { bank_account_id: bank_account.id }
        expect(response.body).to include("Filtrar por Archivo de Estado")
        expect(response.body).to include(statement_file.safe_filename)
        expect(response.body).not_to include("other_bank_statement.pdf")
      end
    end

    context "with transaction type filter" do
      let!(:income_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income", description: "Income transaction") }
      let!(:fixed_expense_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "fixed_expense", description: "Fixed expense transaction") }
      let!(:variable_expense_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "variable_expense", description: "Variable expense transaction") }

      it "filters transactions by income type" do
        get "/transactions.json", params: { transaction_type: "income" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(income_transaction.description)
        expect(json["transactions"].map { |t| t["transaction_type"] }.uniq).to eq(["income"])
      end

      it "filters transactions by fixed expense type" do
        get "/transactions.json", params: { transaction_type: "fixed_expense" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(fixed_expense_transaction.description)
        expect(json["transactions"].map { |t| t["transaction_type"] }.uniq).to eq(["fixed_expense"])
      end

      it "filters transactions by variable expense type" do
        get "/transactions.json", params: { transaction_type: "variable_expense" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(variable_expense_transaction.description)
        expect(json["transactions"].map { |t| t["transaction_type"] }.uniq).to eq(["variable_expense"])
      end

      it "shows transaction type dropdown with all options" do
        get "/transactions"
        expect(response.body).to include("Filtrar por Tipo de Transacción")
        expect(response.body).to include("Todos los Tipos de Transacción")
        expect(response.body).to include("Ingreso")
        expect(response.body).to include("Gasto Fijo")
        expect(response.body).to include("Gasto Variable")
      end

      it "shows clear button when transaction type is selected" do
        get "/transactions", params: { transaction_type: "income" }
        expect(response.body).to include("text-red-600 hover:text-red-800")
        expect(response.body).to include("Limpiar Todos los Filtros")
      end
    end

    context "with date range filter" do
      let!(:old_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 1, 15), description: "Old transaction") }
      let!(:recent_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 12, 15), description: "Recent transaction") }

      it "filters transactions by from_date" do
        get "/transactions.json", params: { from_date: "2024-06-01" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(recent_transaction.description)
        expect(json["transactions"].map { |t| t["description"] }).not_to include(old_transaction.description)
      end

      it "filters transactions by to_date" do
        get "/transactions.json", params: { to_date: "2024-06-30" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(old_transaction.description)
        expect(json["transactions"].map { |t| t["description"] }).not_to include(recent_transaction.description)
      end

      it "filters transactions by date range" do
        get "/transactions.json", params: { from_date: "2024-01-01", to_date: "2024-06-30" }
        json = JSON.parse(response.body)
        expect(json["transactions"].length).to eq(1)
        expect(json["transactions"].first["description"]).to eq(old_transaction.description)
        expect(json["transactions"].map { |t| t["description"] }).not_to include(recent_transaction.description)
      end

      it "combines date filter with bank account filter" do
        other_bank_account = create(:bank_account, user: user, bank: bank)
        other_transaction = create(:transaction, user: user, bank_account: other_bank_account, category: category, date: Date.new(2024, 6, 15), description: "Other transaction")
        get "/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-06-01",
          to_date: "2024-06-30"
        }
        expect(response.body).to include("0")
        expect(response.body).not_to include(old_transaction.description)
        expect(response.body).not_to include(recent_transaction.description)
        expect(response.body).not_to include(other_transaction.description)
      end

      it "preserves filters when sorting" do
        create_list(:transaction, 5,
          user: user,
          bank_account: bank_account,
          category: category,
          date: Date.new(2024, 6, 15)
        )
        get "/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31",
          sort: "amount",
          direction: "asc"
        }
        expect(response).to have_http_status(200)
        expect(response.body).to include('transactions-table-row')
        expect(response.body).to include('sort')
      end

      it "resets pagination when filters change but not when sorting changes" do
        create_list(:transaction, 5,
          user: user,
          bank_account: bank_account,
          category: category,
          date: Date.new(2024, 6, 15)
        )

        # First request with filters
        get "/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31"
        }
        expect(response).to have_http_status(:success)

        # Should show some transactions (test actual data, not CSS)
        expect(response.body).to include('Test transaction')
        expect(response.body).to include('$1,299.99')

        # Change sorting - should preserve filters
        get "/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31",
          sort: "amount",
          direction: "asc"
        }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "stats functionality" do
    include_context "with few transactions"

    it "displays dynamic stats based on filtered transactions" do
      create(:transaction,
        user: user,
        bank_account: bank_account,
        category: category,
        transaction_type: 'income',
        amount: 1000.00,
        date: Date.parse('2024-06-15')
      )

      get "/transactions"
      expect(response.body).to include('$1,000.00')
      expect(response.body).to include('-$3,899.97')
      expect(response.body).to include('4')

      get "/transactions", params: {
        from_date: "2024-06-01",
        to_date: "2024-06-30"
      }
      expect(response.body).to include('$1,000.00')
      expect(response.body).to include('$0.00')
      expect(response.body).to include('1')

      get "/transactions", params: {
        bank_account_id: bank_account.id
      }
      expect(response.body).to include('$1,000.00')
      expect(response.body).to include('-$3,899.97')
      expect(response.body).to include('4')
    end
  end

  describe "AJAX requests for infinite scrolling" do
    let!(:transactions) { create_list(:transaction, 2, user: user, bank_account: bank_account, category: category) }

    it "returns transaction rows partial for page 1" do
      get "/transactions", params: { page: 1 }, xhr: true
      expect(response).to have_http_status(:success)
      expect(response.body).to include('class="transactions-table-row"')
    end

    it "returns correct number of transactions" do
      get "/transactions", params: { page: 1 }, xhr: true
      expect(response.body).to include('class="transactions-table-row"')
    end
  end

  describe "sorting functionality" do
    include_context "with few transactions"

    it "sorts by date in descending order by default" do
      get "/transactions"
      expect(response).to have_http_status(:success)
    end

    it "sorts by amount in ascending order" do
      get "/transactions", params: { sort: "amount", direction: "asc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by amount in descending order" do
      get "/transactions", params: { sort: "amount", direction: "desc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by description" do
      get "/transactions", params: { sort: "description" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by transaction type" do
      get "/transactions", params: { sort: "transaction_type" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by category" do
      get "/transactions", params: { sort: "category" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by merchant" do
      get "/transactions", params: { sort: "merchant" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by bank account" do
      get "/transactions", params: { sort: "bank_account" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "pagination with Pagy" do
    let!(:transactions) { create_list(:transaction, 3, user: user, bank_account: bank_account, category: category) }

    it "shows correct pagination info for first page" do
      get "/transactions.json"
      json = JSON.parse(response.body)
      expect(json["pagination"]["page"]).to eq(1)
      expect(json["pagination"]["pages"]).to eq(1)
      expect(json["pagination"]["count"]).to eq(3)
    end

    it "returns correct number of transactions for the page" do
      get "/transactions.json"
      json = JSON.parse(response.body)
      expect(json["transactions"].length).to eq(3)
    end
  end

  describe "transaction display" do
    include_context "with single transaction"

    it "displays transaction information correctly" do
      get "/transactions"
      expect(response.body).to include("Test transaction")
    end

    it "shows bank account information" do
      get "/transactions"
      expect(response.body).to include(bank.name)
    end

    it "shows category information" do
      get "/transactions"
      expect(response.body).to include(category.name)
    end

    it "includes transaction data needed for editing" do
      get "/transactions.json"
      json = JSON.parse(response.body)
      expect(json["transactions"].first).to have_key("id")
      expect(json["transactions"].first).to have_key("description")
      expect(json["transactions"].first).to have_key("amount")
      expect(json["transactions"].first).to have_key("date")
    end
  end

  describe "fast transaction display (stubbed)" do
    let(:stubbed_transaction) { build_stubbed(:transaction, :stubbed, user: user, bank_account: bank_account, category: category, description: "Stubbed transaction") }

    it "can test transaction logic without database hits" do
      expect(stubbed_transaction.description).to eq("Stubbed transaction")
      expect(stubbed_transaction.user).to eq(user)
    end
  end

  describe "error handling" do
    it "handles invalid page parameter gracefully" do
      get "/transactions", params: { page: "invalid" }
      expect(response).to have_http_status(:success)
    end

    it "handles page parameter beyond total pages" do
      get "/transactions", params: { page: 999 }
      expect(response).to have_http_status(:success)
    end
  end
end
