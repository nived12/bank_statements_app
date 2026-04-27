# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user) }

  before { sign_in_user(user) }

  describe "GET /transactions" do
    it "renders empty state" do
      get "/transactions"
      expect(response).to have_http_status(:success)
    end

    it "returns JSON with pagination" do
      create_list(:transaction, 3, user: user, bank_account: bank_account, category: category)

      get "/transactions.json"
      json = JSON.parse(response.body)

      expect(json["transactions"].length).to eq(3)
      expect(json["pagination"]["count"]).to eq(3)
    end

    it "filters by transaction type" do
      create(:transaction, user: user, bank_account: bank_account, category: category, transaction_type: "income")
      create(
        :transaction, user: user, bank_account: bank_account, category: category,
        transaction_type: "fixed_expense"
      )

      get "/transactions.json", params: { transaction_type: "income" }
      json = JSON.parse(response.body)

      expect(json["transactions"].length).to eq(1)
      expect(json["transactions"].first["transaction_type"]).to eq("income")
    end

    it "filters by date range" do
      create(:transaction, user: user, bank_account: bank_account, category: category, date: Date.new(2024, 1, 15))
      recent = create(
        :transaction, user: user, bank_account: bank_account, category: category,
        date: Date.new(2024, 12, 15)
      )

      get "/transactions.json", params: { from_date: "2024-06-01" }
      json = JSON.parse(response.body)

      expect(json["transactions"].map { |t| t["id"] }).to eq([recent.id])
    end

    it "sorts transactions" do
      create(:transaction, user: user, bank_account: bank_account, category: category)

      get "/transactions", params: { sort: "amount" }
      expect(response).to have_http_status(:success)
    end

    it "handles invalid page parameter" do
      get "/transactions", params: { page: "invalid" }
      expect(response).to have_http_status(:success)
    end

    context "filtering by category_ids" do
      let(:parent_category) { create(:category, user: user) }
      let(:child_category) { create(:category, user: user, parent: parent_category) }
      let(:other_category) { create(:category, user: user) }

      it "returns transactions for the given category and its children" do
        txn_parent = create(:transaction, user: user, bank_account: bank_account, category: parent_category)
        txn_child = create(:transaction, user: user, bank_account: bank_account, category: child_category)
        create(:transaction, user: user, bank_account: bank_account, category: other_category)

        get "/transactions.json", params: { category_ids: [parent_category.id] }
        json = JSON.parse(response.body)

        returned_ids = json["transactions"].map { |t| t["id"] }
        expect(returned_ids).to contain_exactly(txn_parent.id, txn_child.id)
      end

      it "filters by multiple categories simultaneously" do
        txn_parent = create(:transaction, user: user, bank_account: bank_account, category: parent_category)
        txn_other = create(:transaction, user: user, bank_account: bank_account, category: other_category)
        create(:transaction, user: user, bank_account: bank_account)

        get "/transactions.json", params: { category_ids: [parent_category.id, other_category.id] }
        json = JSON.parse(response.body)

        returned_ids = json["transactions"].map { |t| t["id"] }
        expect(returned_ids).to contain_exactly(txn_parent.id, txn_other.id)
      end

      it "does not return transactions from other users categories" do
        other_user = create(:user)
        other_bank_account = create(:bank_account, user: other_user)
        other_user_category = create(:category, user: other_user)
        create(:transaction, user: other_user, bank_account: other_bank_account, category: other_user_category)

        get "/transactions.json", params: { category_ids: [other_user_category.id] }
        json = JSON.parse(response.body)

        expect(json["transactions"]).to be_empty
      end
    end
  end

  describe "POST /transactions (web)" do
    context "when user email is not confirmed" do
      let(:unconfirmed_user) { create(:user) }

      before { sign_in_user(unconfirmed_user) }

      it "redirects back with a flash alert" do
        account = create(:bank_account, user: unconfirmed_user)
        post "/transactions", params: {
          transaction: {
            bank_account_id: account.id,
            description: "Test",
            amount: 100,
            date: Date.current.to_s,
            transaction_type: "income"
          }
        }

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include(I18n.t("email_confirmations.required_to_write"))
      end
    end
  end
end
