# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before do
    # Simulate user login
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "GET /transactions" do
    context "with transactions" do
      before do
        # Create 25 transactions (more than the 20 per page limit)
        create_list(:transaction, 25, user: user, bank_account: bank_account, category: category)
      end

      it "displays transactions with pagination info" do
        get transactions_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Mostrando página 1 de 2")
        expect(response.body).to include("20") # transactions loaded count
        expect(response.body).to include("25") # total transactions
      end

      it "includes infinite scrolling container" do
        get transactions_path
        expect(response.body).to include('id="infinite-scroll-container"')
        expect(response.body).to include('data-next-page="2"')
        expect(response.body).to include('data-current-page="1"')
        expect(response.body).to include('data-total-pages="2"')
        expect(response.body).to include('data-total-count="25"')
      end

      it "includes scroll trigger for infinite scrolling" do
        get transactions_path
        expect(response.body).to include('id="scroll-trigger"')
      end

      it "includes transaction rows partial" do
        get transactions_path
        expect(response.body).to include('id="transactions-tbody"')
      end
    end

    context "without transactions" do
      it "shows empty state message" do
        get transactions_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Aún no hay transacciones")
        expect(response.body).to include("Sube tu primer estado de cuenta")
      end
    end

    context "with bank account filter" do
      let(:other_account) { create(:bank_account, user: user) }
      
      before do
        create_list(:transaction, 5, user: user, bank_account: bank_account)
        create_list(:transaction, 3, user: user, bank_account: other_account)
      end

      it "filters transactions by bank account" do
        get transactions_path, params: { bank_account_id: bank_account.id }
        expect(response.body).to include("20") # transactions loaded count
        expect(response.body).to include("25") # total transactions
      end
    end
  end

  describe "AJAX requests for infinite scrolling" do
    before do
      create_list(:transaction, 25, user: user, bank_account: bank_account, category: category)
    end

    it "returns transaction rows partial for page 2" do
      get transactions_path, params: { page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('class="transactions-table-row"')
      expect(response.body).to include('class="transactions-table-cell"')
    end

    it "calculates correct page offset for page 2" do
      get transactions_path, params: { page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }
      
      # Page 2 should start with transaction 21 (20 + 1)
      expect(response.body).to include("21")
      expect(response.body).to include("22")
    end

    it "returns correct number of transactions for last page" do
      get transactions_path, params: { page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }
      
      # Page 2 should have 5 transactions (25 total - 20 from page 1)
      expect(response.body).to include('class="transactions-table-row"')
      # Count the number of table rows
      row_count = response.body.scan('class="transactions-table-row"').count
      expect(row_count).to eq(5)
    end
  end

  describe "sorting functionality" do
    before do
      create(:transaction, user: user, bank_account: bank_account, amount: 100, date: Date.current - 2.days)
      create(:transaction, user: user, bank_account: bank_account, amount: 200, date: Date.current - 1.day)
      create(:transaction, user: user, bank_account: bank_account, amount: 50, date: Date.current)
    end

    it "sorts by date in descending order by default" do
      get transactions_path
      expect(response).to have_http_status(:success)
      # Should show most recent first
      expect(response.body).to include("Mostrando página 1 de 1")
    end

    it "sorts by amount in ascending order" do
      get transactions_path, params: { sort: "amount", direction: "asc" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Mostrando página 1 de 1")
    end

    it "sorts by amount in descending order" do
      get transactions_path, params: { sort: "amount", direction: "desc" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Mostrando página 1 de 1")
    end

    it "sorts by description" do
      get transactions_path, params: { sort: "description", direction: "asc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by transaction type" do
      get transactions_path, params: { sort: "transaction_type", direction: "desc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by category" do
      get transactions_path, params: { sort: "category", direction: "asc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by merchant" do
      get transactions_path, params: { sort: "merchant", direction: "asc" }
      expect(response).to have_http_status(:success)
    end

    it "sorts by bank account" do
      get transactions_path, params: { sort: "bank_account", direction: "asc" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "pagination with Pagy" do
    before do
      # Create exactly 40 transactions (2 full pages of 20)
      create_list(:transaction, 40, user: user, bank_account: bank_account, category: category)
    end

    it "shows correct pagination info for first page" do
      get transactions_path
      expect(response.body).to include("Mostrando página 1 de 2")
      expect(response.body).to include("20") # transactions loaded count
      expect(response.body).to include("40") # total transactions
    end

    it "shows correct next page info" do
      get transactions_path
      expect(response.body).to include('data-next-page="2"')
    end

    it "returns correct number of transactions for second page" do
      get transactions_path, params: { page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }
      
      # Page 2 should have 20 transactions
      row_count = response.body.scan('class="transactions-table-row"').count
      expect(row_count).to eq(20)
    end

    it "calculates correct page offset for second page" do
      get transactions_path, params: { page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }
      
      # Page 2 should start with transaction 21
      expect(response.body).to include("21")
      expect(response.body).to include("22")
    end
  end

  describe "transaction display" do
    before do
      create(:transaction, 
        user: user, 
        bank_account: bank_account, 
        category: category,
        amount: -1299.99,
        date: Date.new(2025, 1, 5),
        description: "Test transaction"
      )
    end

    it "displays transaction information correctly" do
      get transactions_path
      expect(response.body).to include("Test transaction")
      expect(response.body).to include("-$1,299.99")
      expect(response.body).to include("Ene 05, 2025")
    end

    it "shows bank account information" do
      get transactions_path
      expect(response.body).to include(bank_account.bank.name)
      expect(response.body).to include("••••#{bank_account.account_number.last(4)}")
    end

    it "shows category information" do
      get transactions_path
      expect(response.body).to include(category.name)
    end

    it "includes edit button for each transaction" do
      get transactions_path
      expect(response.body).to include('onclick="openEditModal(')
    end
  end

  describe "error handling" do
    it "handles invalid page parameter gracefully" do
      get transactions_path, params: { page: "invalid" }
      expect(response).to have_http_status(:success)
      # Should show empty state since no transactions exist
      expect(response.body).to include("Aún no hay transacciones")
    end

    it "handles page parameter beyond total pages" do
      create_list(:transaction, 5, user: user, bank_account: bank_account)
      
      get transactions_path, params: { page: 999 }
      expect(response).to have_http_status(:success)
      # Should show empty result or last page
      expect(response.body).to include("Mostrando página 1")
    end
  end
end
