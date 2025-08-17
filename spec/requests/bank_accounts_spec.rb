# spec/requests/bank_accounts_spec.rb
require "rails_helper"

RSpec.describe "BankAccounts", type: :request do
  let(:user) { create(:user) }
  let(:bbva_bank) { Bank.find_by(code: "bbva") }
  let(:santander_bank) { Bank.find_by(code: "santander") }

  before do
    # Simulate user login
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "GET /bank_accounts" do
    it "displays bank accounts with bank information" do
      account1 = create(:bank_account, :bbva, user: user, account_number: "1234")
      account2 = create(:bank_account, :santander, user: user, account_number: "5678")

      get bank_accounts_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BBVA Bancomer")
      expect(response.body).to include("Santander")
      expect(response.body).to include("1234")
      expect(response.body).to include("5678")
    end
  end

  describe "GET /bank_accounts/new" do
    it "displays form with bank selection dropdown" do
      get new_bank_account_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bank")
      expect(response.body).to include("BBVA Bancomer")
      expect(response.body).to include("Santander")
      expect(response.body).to include("Otro Banco")
    end

    it "includes supported banks in the dropdown" do
      get new_bank_account_path
      expect(response.body).to include("value=\"#{bbva_bank.id}\"")
      expect(response.body).to include("value=\"#{santander_bank.id}\"")
    end
  end

  describe "POST /bank_accounts" do
    let(:valid_params) do
      {
        bank_account: {
          bank_id: bbva_bank.id,
          account_number: "1234567890",
          currency: "MXN",
          opening_balance: "1000.50",
          custom_name: "My BBVA Account"
        }
      }
    end

    let(:invalid_params) do
      {
        bank_account: {
          bank_id: nil,
          account_number: "",
          currency: "MXN",
          opening_balance: "1000.50"
        }
      }
    end

    it "creates a new bank account with valid parameters" do
      expect {
        post bank_accounts_path, params: valid_params
      }.to change(BankAccount, :count).by(1)

      expect(response).to redirect_to(bank_accounts_path)

      bank_account = BankAccount.last
      expect(bank_account.bank).to eq(bbva_bank)
      expect(bank_account.account_number).to eq("1234567890")
      expect(bank_account.custom_name).to eq("My BBVA Account")
    end

    it "creates account without custom name" do
      params_without_custom = valid_params.deep_dup
      params_without_custom[:bank_account][:custom_name] = ""

      expect {
        post bank_accounts_path, params: params_without_custom
      }.to change(BankAccount, :count).by(1)

      bank_account = BankAccount.last
      expect(bank_account.custom_name).to be_blank
    end

    it "fails with invalid parameters" do
      expect {
        post bank_accounts_path, params: invalid_params
      }.not_to change(BankAccount, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "fails without bank selection" do
      params_without_bank = valid_params.deep_dup
      params_without_bank[:bank_account][:bank_id] = ""

      expect {
        post bank_accounts_path, params: params_without_bank
      }.not_to change(BankAccount, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /bank_accounts/:id/edit" do
    let(:bank_account) { create(:bank_account, :bbva, user: user) }

    it "displays edit form with current bank selected" do
      get "/bank_accounts/#{bank_account.id}/edit"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("selected=\"selected\" value=\"#{bbva_bank.id}\"")
    end
  end

  describe "PATCH /bank_accounts/:id" do
    let(:bank_account) { create(:bank_account, :bbva, user: user) }

    it "updates bank account with new bank" do
      patch "/bank_accounts/#{bank_account.id}", params: {
        bank_account: {
          bank_id: santander_bank.id,
          custom_name: "Updated Account"
        }
      }

      expect(response).to redirect_to("/bank_accounts")

      bank_account.reload
      expect(bank_account.bank).to eq(santander_bank)
      expect(bank_account.custom_name).to eq("Updated Account")
    end

    it "updates custom name only" do
      patch "/bank_accounts/#{bank_account.id}", params: {
        bank_account: {
          custom_name: "New Custom Name"
        }
      }

      expect(response).to redirect_to("/bank_accounts")

      bank_account.reload
      expect(bank_account.custom_name).to eq("New Custom Name")
      expect(bank_account.bank).to eq(bbva_bank) # Bank unchanged
    end
  end

  describe "DELETE /bank_accounts/:id" do
    let!(:bank_account) { create(:bank_account, :bbva, user: user) }

    it "deletes the bank account" do
      expect {
        delete "/bank_accounts/#{bank_account.id}"
      }.to change(BankAccount, :count).by(-1)

      expect(response).to redirect_to("/bank_accounts")
    end
  end
end
