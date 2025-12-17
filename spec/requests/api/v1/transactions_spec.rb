# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:access_token) { Auth::GenerateTokensService.call(user).payload[:access_token] }
  let(:auth_headers) { { "Authorization" => "Bearer #{access_token}" } }
  let(:bank) { create(:bank, name: "Test Bank") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, opening_balance: 1000) }
  let(:category) { create(:category, user: user, name: "Food") }

  describe "GET /api/v1/transactions" do
    context "when authenticated" do
      let!(:transaction1) do
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: -50.0, transaction_type: "variable_expense", date: Date.current,
               description: "Groceries", merchant: "Walmart", source: :manual)
      end
      let!(:transaction2) do
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: 100.0, transaction_type: "income", date: Date.current - 1.day,
               description: "Salary", source: :manual)
      end

      it "returns transactions list successfully" do
        get "/api/v1/transactions", headers: auth_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["data"]).to be_present
        expect(json["data"]["transactions"]).to be_an(Array)
        expect(json["data"]["transactions"].length).to eq(2)
        expect(json["meta"]).to be_present
      end

      it "includes transaction details" do
        get "/api/v1/transactions", headers: auth_headers

        json = JSON.parse(response.body)
        transaction = json["data"]["transactions"].first

        expect(transaction["id"]).to be_present
        expect(transaction["date"]).to be_present
        expect(transaction["description"]).to be_present
        expect(transaction["amount"]).to be_a(Numeric)
        expect(transaction["transaction_type"]).to be_present
        expect(transaction["source"]).to be_present
        expect(transaction["bank_account"]).to be_present
        expect(transaction["is_transfer"]).to be_in([true, false])
      end

      it "includes pagination metadata" do
        get "/api/v1/transactions", headers: auth_headers

        json = JSON.parse(response.body)
        pagination = json["meta"]["pagination"]

        expect(pagination["current_page"]).to eq(1)
        expect(pagination["total_pages"]).to be >= 1
        expect(pagination["total_items"]).to eq(2)
        expect(pagination["page_size"]).to eq(20)
        expect(pagination["from"]).to eq(1)
        expect(pagination["to"]).to eq(2)
        expect(pagination["next_page"]).to be_nil
        expect(pagination["prev_page"]).to be_nil
      end

      it "includes statistics in meta" do
        get "/api/v1/transactions", headers: auth_headers

        json = JSON.parse(response.body)
        stats = json["meta"]["stats"]

        expect(stats["total_transactions"]).to eq(2)
        expect(stats["income_total"]).to eq(100.0)
        expect(stats["expenses_total"]).to eq(50.0)
        expect(stats["income_count"]).to eq(1)
        expect(stats["variable_expense_count"]).to eq(1)
        expect(stats["fixed_expense_count"]).to eq(0)
      end

      it "supports pagination with page_token" do
        # Clear existing transactions created in let! blocks
        Transaction.where(user: user).delete_all
        create_list(:transaction, 25, user: user, bank_account: bank_account, category: category, source: :manual)

        get "/api/v1/transactions?page_token=2&page_size=10", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(10)
        expect(json["meta"]["pagination"]["current_page"]).to eq(2)
        expect(json["meta"]["pagination"]["next_page"]).to eq(3)
        expect(json["meta"]["pagination"]["prev_page"]).to eq(1)
      end

      it "supports pagination with page param" do
        # Clear existing transactions created in let! blocks
        Transaction.where(user: user).delete_all
        create_list(:transaction, 25, user: user, bank_account: bank_account, category: category, source: :manual)

        get "/api/v1/transactions?page=2&page_size=10", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(10)
        expect(json["meta"]["pagination"]["current_page"]).to eq(2)
      end

      it "caps page_size at 100" do
        # Clear existing transactions and create many
        Transaction.where(user: user).delete_all
        create_list(:transaction, 110, user: user, bank_account: bank_account, category: category, source: :manual)

        get "/api/v1/transactions?page_size=200", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["meta"]["pagination"]["page_size"]).to eq(100)
        expect(json["data"]["transactions"].length).to eq(100)
      end

      it "filters by bank_account_id" do
        other_bank_account = create(:bank_account, user: user, bank: bank)
        create(:transaction, user: user, bank_account: other_bank_account, category: category, source: :manual)

        get "/api/v1/transactions?bank_account_id=#{bank_account.id}", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(2)
        expect(json["meta"]["filters"]["bank_account_id"]).to eq(bank_account.id.to_s)
      end

      it "filters by transaction_type" do
        get "/api/v1/transactions?transaction_type=income", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(1)
        expect(json["data"]["transactions"].first["transaction_type"]).to eq("income")
        expect(json["meta"]["filters"]["transaction_type"]).to eq("income")
      end

      it "filters by date range" do
        from_date = (Date.current - 1.day).to_s
        to_date = Date.current.to_s

        get "/api/v1/transactions?from_date=#{from_date}&to_date=#{to_date}", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(2)
        expect(json["meta"]["filters"]["from_date"]).to eq(from_date)
        expect(json["meta"]["filters"]["to_date"]).to eq(to_date)
      end

      it "supports search by description" do
        get "/api/v1/transactions?search=Groceries", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(1)
        expect(json["data"]["transactions"].first["description"]).to include("Groceries")
        expect(json["meta"]["filters"]["search"]).to eq("Groceries")
      end

      it "supports sorting" do
        get "/api/v1/transactions?sort=amount&direction=asc", headers: auth_headers

        json = JSON.parse(response.body)
        amounts = json["data"]["transactions"].map { |t| t["amount"] }
        expect(amounts).to eq(amounts.sort)
      end

      it "handles category being nil" do
        transaction_without_category = create(:transaction, user: user, bank_account: bank_account,
                                                           category: nil, source: :manual)

        get "/api/v1/transactions", headers: auth_headers

        json = JSON.parse(response.body)
        transaction = json["data"]["transactions"].find { |t| t["id"] == transaction_without_category.id }
        expect(transaction["category"]).to be_nil
      end

      it "only returns current user's transactions" do
        other_user = create(:user, :confirmed)
        other_bank_account = create(:bank_account, user: other_user, bank: bank)
        create(:transaction, user: other_user, bank_account: other_bank_account, category: category, source: :manual)

        get "/api/v1/transactions", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["transactions"].length).to eq(2)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/transactions"

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to be_present
      end
    end
  end

  describe "GET /api/v1/transactions/:id" do
    let!(:transaction) do
      create(:transaction, user: user, bank_account: bank_account, category: category,
             source: :manual, merchant: "Test Store", reference: "REF123")
    end

    context "when authenticated" do
      it "returns transaction details successfully" do
        get "/api/v1/transactions/#{transaction.id}", headers: auth_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["data"]["id"]).to eq(transaction.id)
        expect(json["data"]["description"]).to eq(transaction.description)
        expect(json["data"]["amount"]).to eq(transaction.amount.to_f)
        expect(json["data"]["merchant"]).to eq("Test Store")
        expect(json["data"]["reference"]).to eq("REF123")
      end

      it "includes bank account details" do
        get "/api/v1/transactions/#{transaction.id}", headers: auth_headers

        json = JSON.parse(response.body)
        bank_account_data = json["data"]["bank_account"]

        expect(bank_account_data["id"]).to eq(bank_account.id)
        expect(bank_account_data["name"]).to be_present
        expect(bank_account_data["account_type"]).to eq(bank_account.account_type)
      end

      it "includes category details when present" do
        get "/api/v1/transactions/#{transaction.id}", headers: auth_headers

        json = JSON.parse(response.body)
        category_data = json["data"]["category"]

        expect(category_data["id"]).to eq(category.id)
        expect(category_data["name"]).to eq(category.name)
        expect(category_data).to have_key("icon")
      end

      it "returns 404 for non-existent transaction" do
        get "/api/v1/transactions/999999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("TRANSACTION_NOT_FOUND")
      end

      it "returns 404 for other user's transaction" do
        other_user = create(:user, :confirmed)
        other_bank_account = create(:bank_account, user: other_user, bank: bank)
        other_transaction = create(:transaction, user: other_user, bank_account: other_bank_account,
                                                 category: category, source: :manual)

        get "/api/v1/transactions/#{other_transaction.id}", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/transactions/#{transaction.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/transactions" do
    context "when authenticated" do
      let(:valid_params) do
        {
          transaction: {
            bank_account_id: bank_account.id,
            date: Date.current.to_s,
            description: "Test transaction",
            amount: 100.50,
            transaction_type: "income",
            category_id: category.id,
            merchant: "Test Merchant",
            reference: "REF-001"
          }
        }
      end

      it "creates a new transaction successfully" do
        expect {
          post "/api/v1/transactions", params: valid_params, headers: auth_headers, as: :json
        }.to change(Transaction, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json["data"]["description"]).to eq("Test transaction")
        expect(json["data"]["amount"]).to eq(100.50)
        expect(json["data"]["source"]).to eq("manual")
        expect(json["message"]).to eq("Transaction created successfully")
      end

      it "sanitizes money field with commas" do
        valid_params[:transaction][:amount] = "1,234.56"

        post "/api/v1/transactions", params: valid_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["data"]["amount"]).to eq(1234.56)
      end

      it "returns validation errors for invalid data" do
        invalid_params = valid_params.deep_merge(transaction: { description: "xyz" })

        post "/api/v1/transactions", params: invalid_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["message"]).to eq("Failed to create transaction")
        expect(json["error"]["details"]).to be_an(Array)
      end

      it "requires bank_account_id" do
        invalid_params = valid_params.tap { |p| p[:transaction].delete(:bank_account_id) }

        post "/api/v1/transactions", params: invalid_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        post "/api/v1/transactions", params: { transaction: {} }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/transactions/:id" do
    let!(:transaction) do
      create(:transaction, user: user, bank_account: bank_account, category: category,
             source: :manual, description: "Original description", amount: 50.0)
    end

    context "when authenticated" do
      it "updates transaction successfully" do
        patch "/api/v1/transactions/#{transaction.id}",
              params: { transaction: { description: "Updated description", amount: 75.0 } },
              headers: auth_headers, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["data"]["description"]).to eq("Updated description")
        expect(json["data"]["amount"]).to eq(-75.0)  # Negative for expense
        expect(json["message"]).to eq("Transaction updated successfully")
      end

      it "prevents updating statement file transactions" do
        statement_transaction = create(:transaction, user: user, bank_account: bank_account,
                                                     category: category, source: :statement_file)

        patch "/api/v1/transactions/#{statement_transaction.id}",
              params: { transaction: { description: "New description" } },
              headers: auth_headers, as: :json

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UPDATE_NOT_ALLOWED")
      end

      it "returns validation errors for invalid updates" do
        patch "/api/v1/transactions/#{transaction.id}",
              params: { transaction: { description: "ab" } },
              headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "returns 404 for other user's transaction" do
        other_user = create(:user, :confirmed)
        other_bank_account = create(:bank_account, user: other_user, bank: bank)
        other_transaction = create(:transaction, user: other_user, bank_account: other_bank_account,
                                                 category: category, source: :manual)

        patch "/api/v1/transactions/#{other_transaction.id}",
              params: { transaction: { description: "Hacked!" } },
              headers: auth_headers, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        patch "/api/v1/transactions/#{transaction.id}", params: { transaction: {} }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/transactions/:id" do
    let!(:transaction) do
      create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual)
    end

    context "when authenticated" do
      it "deletes transaction successfully" do
        expect {
          delete "/api/v1/transactions/#{transaction.id}", headers: auth_headers
        }.to change(Transaction, :count).by(-1)

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Transaction deleted successfully")
      end

      it "prevents deleting statement file transactions" do
        statement_transaction = create(:transaction, user: user, bank_account: bank_account,
                                                     category: category, source: :statement_file)

        expect {
          delete "/api/v1/transactions/#{statement_transaction.id}", headers: auth_headers
        }.not_to change(Transaction, :count)

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("DELETE_NOT_ALLOWED")
      end

      it "returns 404 for non-existent transaction" do
        delete "/api/v1/transactions/999999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 for other user's transaction" do
        other_user = create(:user, :confirmed)
        other_bank_account = create(:bank_account, user: other_user, bank: bank)
        other_transaction = create(:transaction, user: other_user, bank_account: other_bank_account,
                                                 category: category, source: :manual)

        expect {
          delete "/api/v1/transactions/#{other_transaction.id}", headers: auth_headers
        }.not_to change(Transaction, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        delete "/api/v1/transactions/#{transaction.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/transactions/summary" do
    context "when authenticated" do
      let!(:income_transaction) do
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: 1000.0, transaction_type: "income", date: Date.current, source: :manual)
      end
      let!(:expense_transaction) do
        create(:transaction, user: user, bank_account: bank_account, category: category,
               amount: -250.0, transaction_type: "variable_expense", date: Date.current, source: :manual)
      end

      it "returns transaction summary successfully" do
        get "/api/v1/transactions/summary", headers: auth_headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["data"]["stats"]).to be_present
        expect(json["meta"]).to be_present
      end

      it "includes correct statistics" do
        get "/api/v1/transactions/summary", headers: auth_headers

        json = JSON.parse(response.body)
        stats = json["data"]["stats"]

        expect(stats["total_transactions"]).to eq(2)
        expect(stats["income_total"]).to eq(1000.0)
        expect(stats["expenses_total"]).to eq(250.0)
        expect(stats["equity_total"]).to eq(750.0)
        expect(stats["income_count"]).to eq(1)
        expect(stats["variable_expense_count"]).to eq(1)
        expect(stats["fixed_expense_count"]).to eq(0)
        expect(stats["category_count"]).to be >= 1
      end

      it "respects filters" do
        get "/api/v1/transactions/summary?transaction_type=income", headers: auth_headers

        json = JSON.parse(response.body)
        stats = json["data"]["stats"]

        expect(stats["total_transactions"]).to eq(1)
        expect(stats["income_total"]).to eq(1000.0)
        expect(stats["expenses_total"]).to eq(0.0)
        expect(json["meta"]["filters"]["transaction_type"]).to eq("income")
      end

      it "respects date range filters" do
        old_transaction = create(:transaction, user: user, bank_account: bank_account,
                                              category: category, amount: -100.0,
                                              transaction_type: "variable_expense",
                                              date: 1.month.ago, source: :manual)

        from_date = Date.current.beginning_of_month.to_s
        get "/api/v1/transactions/summary?from_date=#{from_date}", headers: auth_headers

        json = JSON.parse(response.body)
        stats = json["data"]["stats"]

        expect(stats["total_transactions"]).to eq(2)  # Should not include old_transaction
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/transactions/summary"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
