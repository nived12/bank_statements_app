# spec/requests/bank_accounts_spec.rb
require "rails_helper"

RSpec.describe "BankAccounts", type: :request do
  let(:user) { create(:user) }
  let(:bbva_bank) { create(:bank, :bbva) }
  let(:santander_bank) { create(:bank, :santander) }
  let(:request_timezone) { ActiveSupport::TimeZone["America/Mexico_City"] }
  let(:request_today) { request_timezone.today }

  before do
    sign_in_user(user)
  end

  describe "GET /bank_accounts" do
    before do
      create(:bank_account, user: user, bank: bbva_bank)
      get "/bank_accounts"
    end

    it "returns success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /bank_accounts/new" do
    before do
      get "/bank_accounts/new"
    end

    it "returns success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /bank_accounts" do
    let(:valid_params) do
      {
        bank_account: {
          bank_id: bbva_bank.id,
          account_number: "1234567890",
          custom_name: "My BBVA Account",
          currency: "MXN",
          opening_balance_date: request_today,
          opening_balance: 1000.0
        }
      }
    end

    it "creates a new bank account with valid parameters" do
      expect {
        post "/bank_accounts", params: valid_params
      }.to change(BankAccount, :count).by(1)

      bank_account = BankAccount.last
      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")
      expect(bank_account.bank).to eq(bbva_bank)
      expect(bank_account.account_number).to eq("1234567890")
      expect(bank_account.custom_name).to eq("My BBVA Account")
    end

    it "creates account without custom name" do
      params_without_custom = valid_params.deep_dup
      params_without_custom[:bank_account].delete(:custom_name)

      expect {
        post "/bank_accounts", params: params_without_custom
      }.to change(BankAccount, :count).by(1)

      bank_account = BankAccount.last
      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")
      expect(bank_account.custom_name).to be_nil
    end

    it "creates credit account with correct account_type" do
      credit_params = valid_params.deep_dup
      credit_params[:bank_account][:account_type] = "credit"

      expect {
        post "/bank_accounts", params: credit_params
      }.to change(BankAccount, :count).by(1)

      bank_account = BankAccount.last
      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")
      expect(bank_account.account_type).to eq("credit")
    end

    it "creates debit account with correct account_type" do
      debit_params = valid_params.deep_dup
      debit_params[:bank_account][:account_type] = "debit"

      expect {
        post "/bank_accounts", params: debit_params
      }.to change(BankAccount, :count).by(1)

      bank_account = BankAccount.last
      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")
      expect(bank_account.account_type).to eq("debit")
    end

    it "fails with invalid parameters" do
      invalid_params = valid_params.deep_dup
      invalid_params[:bank_account][:account_number] = ""

      post "/bank_accounts", params: invalid_params

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "fails without bank selection" do
      expect {
        post "/bank_accounts", params: {
          bank_account: {
            custom_name: "My Account",
            account_number: "1234567890",
            currency: "MXN",
            opening_balance_date: request_today,
            opening_balance: 1000.0
          }
        }
      }.not_to change(BankAccount, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /bank_accounts/:id/edit" do
    let(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "displays edit form with current bank selected" do
      get "/bank_accounts/#{bank_account.id}/edit"

      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /bank_accounts/:id" do
    let(:bank_account) do
      create(:bank_account, user: user, bank: bbva_bank, opening_balance_date: request_today)
    end

    it "updates bank account with new bank" do
      patch "/bank_accounts/#{bank_account.id}", params: {
        bank_account: { bank_id: santander_bank.id }
      }

      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")

      bank_account.reload
      expect(bank_account.bank).to eq(santander_bank)
    end

    it "updates custom name only" do
      patch "/bank_accounts/#{bank_account.id}", params: {
        bank_account: { custom_name: "Updated Name" }
      }

      expect(response).to redirect_to("/bank_accounts/#{bank_account.id}")

      bank_account.reload
      expect(bank_account.custom_name).to eq("Updated Name")
    end
  end

  describe "DELETE /bank_accounts/:id" do
    let!(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "deletes the bank account" do
      expect {
        delete "/bank_accounts/#{bank_account.id}"
      }.to change(BankAccount, :count).by(-1)

      expect(response).to redirect_to("/bank_accounts")
    end
  end

  describe "PATCH /bank_accounts/:id/archive" do
    let!(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "archives the account without deleting it" do
      expect {
        patch "/bank_accounts/#{bank_account.id}/archive"
      }.not_to change(BankAccount, :count)

      expect(bank_account.reload).to be_discarded
      expect(response).to redirect_to("/bank_accounts")
    end

    it "hides archived accounts from the active list but shows them in the archived section" do
      patch "/bank_accounts/#{bank_account.id}/archive"
      get "/bank_accounts"

      # Active section should not include the archived account's unarchive path
      # Archived section should include the unarchive path for this account
      expect(response.body).to include(unarchive_bank_account_path(bank_account))
      expect(response.body).not_to include(archive_bank_account_path(bank_account))
    end
  end

  describe "PATCH /bank_accounts/:id/unarchive" do
    let!(:bank_account) { create(:bank_account, user: user, bank: bbva_bank, discarded_at: Time.current) }

    it "restores an archived account" do
      patch "/bank_accounts/#{bank_account.id}/unarchive"

      expect(bank_account.reload).to be_undiscarded
      expect(response).to redirect_to("/bank_accounts")
    end
  end
end
