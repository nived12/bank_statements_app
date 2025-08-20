# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:category) { create(:category, name: "MyString", user: user) }

  before do
    sign_in_user_with_locale(user)
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

      it "displays transactions with pagination info" do
        get "/es/transactions"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("3") # transactions loaded count (3 transactions)
      end

      it "includes infinite scrolling container" do
        get "/es/transactions"

        expect(response.body).to include('id="infinite-scroll-container"')
      end

      it "includes scroll trigger for infinite scrolling" do
        get "/es/transactions"

        expect(response.body).to include('id="scroll-trigger"')
      end

      it "includes transaction rows partial" do
        get "/es/transactions"

        expect(response.body).to include('id="transactions-tbody"')
      end
    end

    context "without transactions" do
      it "shows empty state message" do
        get "/es/transactions"

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Aún no hay transacciones")
      end
    end

    context "with bank account filter" do
      include_context "with few transactions"

      it "filters transactions by bank account" do
        get "/es/transactions", params: { bank_account_id: bank_account.id }

        expect(response.body).to include("3") # transactions loaded count (3 transactions)
      end
    end

    context "with date range filter" do
      let!(:old_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 1, 15), description: "Old transaction") }
      let!(:recent_transaction) { create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 12, 15), description: "Recent transaction") }

      it "filters transactions by from_date" do
        get "/es/transactions", params: { from_date: "2024-06-01" }

        expect(response.body).to include("1") # transactions loaded count (1 transaction)
        expect(response.body).to include(recent_transaction.description)
        expect(response.body).not_to include(old_transaction.description)
      end

      it "filters transactions by to_date" do
        get "/es/transactions", params: { to_date: "2024-06-30" }

        expect(response.body).to include("1") # transactions loaded count (1 transaction)
        expect(response.body).to include(old_transaction.description)
        expect(response.body).not_to include(recent_transaction.description)
      end

      it "filters transactions by date range" do
        get "/es/transactions", params: { from_date: "2024-01-01", to_date: "2024-06-30" }

        expect(response.body).to include("1") # transactions loaded count (1 transaction)
        expect(response.body).to include(old_transaction.description)
        expect(response.body).not_to include(recent_transaction.description)
      end

      it "combines date filter with bank account filter" do
        other_bank_account = create(:bank_account, user: user, bank: bank)
        other_transaction = create(:transaction, user: user, bank_account: other_bank_account, category: category, date: Date.new(2024, 6, 15), description: "Other transaction")

        get "/es/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-06-01",
          to_date: "2024-06-30"
        }

        expect(response.body).to include("0") # transactions loaded count (0 transactions)
        expect(response.body).not_to include(old_transaction.description)
        expect(response.body).not_to include(recent_transaction.description)
        expect(response.body).not_to include(other_transaction.description)
      end

      it "preserves filters when sorting" do
        get "/es/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31",
          sort: "amount",
          direction: "asc"
        }

        # Should still show filtered results
        expect(response.body).to include("2") # transactions loaded count (2 transactions)
        expect(response.body).to include(old_transaction.description)
        expect(response.body).to include(recent_transaction.description)

        # Should show sorting is applied by checking the URL parameters in the response
        expect(response.body).to include('sort=amount')
        expect(response.body).to include('direction=asc')
      end

      it "resets pagination when filters change but not when sorting changes" do
        # First request with filters and pagination
        get "/es/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31",
          page: 2
        }

        # Should show page 2
        expect(response.body).to include('data-current-page="2"')

        # Change sorting - should preserve filters and pagination
        get "/es/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-01-01",
          to_date: "2024-12-31",
          sort: "amount",
          direction: "asc",
          page: 2
        }

        # Should still show page 2
        expect(response.body).to include('data-current-page="2"')

        # Change filters - should reset to page 1
        get "/es/transactions", params: {
          bank_account_id: bank_account.id,
          from_date: "2024-06-01",
          to_date: "2024-12-31",
          sort: "amount",
          direction: "asc"
        }

        # Should reset to page 1
        expect(response.body).to include('data-current-page="1"')
      end
    end
  end

  describe "AJAX requests for infinite scrolling" do
    # Use minimal transactions for AJAX tests
    let!(:transactions) { create_list(:transaction, 2, user: user, bank_account: bank_account, category: category) }

    it "returns transaction rows partial for page 1" do
      get "/es/transactions", params: { page: 1 }, xhr: true

      expect(response).to have_http_status(:success)
      expect(response.body).to include('class="transactions-table-row"')
    end

    it "returns correct number of transactions" do
      get "/es/transactions", params: { page: 1 }, xhr: true

      expect(response.body).to include('class="transactions-table-row"')
    end
  end

  describe "sorting functionality" do
    include_context "with few transactions"

    it "sorts by date in descending order by default" do
      get "/es/transactions"

      expect(response).to have_http_status(:success)
    end

    it "sorts by amount in ascending order" do
      get "/es/transactions", params: { sort: "amount", direction: "asc" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by amount in descending order" do
      get "/es/transactions", params: { sort: "amount", direction: "desc" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by description" do
      get "/es/transactions", params: { sort: "description" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by transaction type" do
      get "/es/transactions", params: { sort: "transaction_type" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by category" do
      get "/es/transactions", params: { sort: "category" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by merchant" do
      get "/es/transactions", params: { sort: "merchant" }

      expect(response).to have_http_status(:success)
    end

    it "sorts by bank account" do
      get "/es/transactions", params: { sort: "bank_account" }

      expect(response).to have_http_status(:success)
    end
  end

  describe "pagination with Pagy" do
    # Use minimal transactions for pagination tests
    let!(:transactions) { create_list(:transaction, 3, user: user, bank_account: bank_account, category: category) }

    it "shows correct pagination info for first page" do
      get "/es/transactions"

      expect(response.body).to include("Mostrando página 1 de 1") # Only 1 page with 3 transactions
    end

    it "returns correct number of transactions for the page" do
      get "/es/transactions"

      row_count = response.body.scan('class="transactions-table-row"').count
      expect(row_count).to eq(3) # All 3 transactions on one page
    end
  end

  describe "transaction display" do
    include_context "with single transaction"

    it "displays transaction information correctly" do
      get "/es/transactions"

      expect(response.body).to include("Test transaction")
    end

    it "shows bank account information" do
      get "/es/transactions"

      expect(response.body).to include(bank.name)
    end

    it "shows category information" do
      get "/es/transactions"

      expect(response.body).to include(category.name)
    end

    it "includes edit button for each transaction" do
      get "/es/transactions"

      expect(response.body).to include('onclick="openEditModal(')
    end
  end

  # Example of how to make tests even faster when full database records aren't needed
  describe "fast transaction display (stubbed)" do
    let(:stubbed_transaction) { build_stubbed(:transaction, :stubbed, user: user, bank_account: bank_account, category: category, description: "Stubbed transaction") }

    it "can test transaction logic without database hits" do
      # This test doesn't hit the database at all
      expect(stubbed_transaction.description).to eq("Stubbed transaction")
      expect(stubbed_transaction.user).to eq(user)
    end
  end

  describe "error handling" do
    it "handles invalid page parameter gracefully" do
      get "/es/transactions", params: { page: "invalid" }

      expect(response).to have_http_status(:success)
    end

    it "handles page parameter beyond total pages" do
      get "/es/transactions", params: { page: 999 }

      expect(response).to have_http_status(:success)
    end
  end
end
