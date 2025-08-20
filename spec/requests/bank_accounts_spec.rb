# spec/requests/bank_accounts_spec.rb
require "rails_helper"

RSpec.describe "BankAccounts", type: :request do
  let(:user) { create(:user) }
  let(:bbva_bank) { create(:bank, name: "bbva") }
  let(:santander_bank) { create(:bank, name: "santander") }

  before do
    sign_in_user_with_locale(user)
  end

  describe "GET /bank_accounts" do
    it "displays bank accounts with bank information" do
      bank_account = create(:bank_account, user: user, bank: bbva_bank)

      get "/es/bank_accounts"

      expect(response).to have_http_status(:success)
      expect(response.body).to include(bank_account.account_number)
      expect(response.body).to include(bbva_bank.name)
    end
  end

  describe "GET /bank_accounts/new" do
    it "displays form with bank selection dropdown" do
      get "/es/bank_accounts/new"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Agregar Nueva Cuenta Bancaria")
      expect(response.body).to include("Banco")
    end

    it "includes supported banks in the dropdown" do
      get "/es/bank_accounts/new"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("BBVA Bancomer")
      expect(response.body).to include("Santander")
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
          opening_balance_date: Date.current,
          opening_balance: 1000.0
        }
      }
    end

    it "creates a new bank account with valid parameters" do
      expect {
        post "/es/bank_accounts", params: valid_params
      }.to change(BankAccount, :count).by(1)

      expect(response).to redirect_to("/es/bank_accounts")

      bank_account = BankAccount.last
      expect(bank_account.bank).to eq(bbva_bank)
      expect(bank_account.account_number).to eq("1234567890")
      expect(bank_account.custom_name).to eq("My BBVA Account")
    end

    it "creates account without custom name" do
      params_without_custom = valid_params.deep_dup
      params_without_custom[:bank_account].delete(:custom_name)

      expect {
        post "/es/bank_accounts", params: params_without_custom
      }.to change(BankAccount, :count).by(1)

      expect(response).to redirect_to("/es/bank_accounts")

      bank_account = BankAccount.last
      expect(bank_account.custom_name).to be_nil
    end

    it "fails with invalid parameters" do
      invalid_params = valid_params.deep_dup
      invalid_params[:bank_account][:account_number] = ""

      post "/es/bank_accounts", params: invalid_params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("es obligatorio")
    end

    it "fails without bank selection" do
      post "/es/bank_accounts", params: {
        bank_account: {
          custom_name: "My Account",
          account_number: "1234567890",
          currency: "MXN",
          opening_balance_date: Date.current,
          opening_balance: 1000.0
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("es obligatorio")
    end
  end

  describe "GET /bank_accounts/:id/edit" do
    let(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "displays edit form with current bank selected" do
      get "/es/bank_accounts/#{bank_account.id}/edit"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("selected=\"selected\"")
    end
  end

  describe "PATCH /bank_accounts/:id" do
    let(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "updates bank account with new bank" do
      patch "/es/bank_accounts/#{bank_account.id}", params: {
        bank_account: { bank_id: santander_bank.id }
      }

      expect(response).to redirect_to("/es/bank_accounts")

      bank_account.reload
      expect(bank_account.bank).to eq(santander_bank)
    end

    it "updates custom name only" do
      patch "/es/bank_accounts/#{bank_account.id}", params: {
        bank_account: { custom_name: "Updated Name" }
      }

      expect(response).to redirect_to("/es/bank_accounts")

      bank_account.reload
      expect(bank_account.custom_name).to eq("Updated Name")
    end
  end

  describe "DELETE /bank_accounts/:id" do
    let!(:bank_account) { create(:bank_account, user: user, bank: bbva_bank) }

    it "deletes the bank account" do
      expect {
        delete "/es/bank_accounts/#{bank_account.id}"
      }.to change(BankAccount, :count).by(-1)

      expect(response).to redirect_to("/es/bank_accounts")
    end
  end
end
