# spec/requests/bank_accounts/statement_files_spec.rb
require "rails_helper"

RSpec.describe "BankAccounts::StatementFiles", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }

  before do
    sign_in_user(user)
  end

  describe "GET /bank_accounts/:bank_account_id/statement_files" do
    it "returns statement files for the bank account" do
      statement_file1 = create(:statement_file, bank_account: bank_account, cutoff_date: 1.month.ago)
      statement_file2 = create(:statement_file, bank_account: bank_account, cutoff_date: Time.zone.today)

      get "/bank_accounts/#{bank_account.id}/statement_files", as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(2)
    end

    it "orders by cutoff_date descending by default" do
      old_statement = create(:statement_file, bank_account: bank_account, cutoff_date: 2.months.ago)
      new_statement = create(:statement_file, bank_account: bank_account, cutoff_date: Time.zone.today)

      get "/bank_accounts/#{bank_account.id}/statement_files", as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.first["id"]).to eq(new_statement.id)
      expect(json.last["id"]).to eq(old_statement.id)
    end

    it "supports custom sorting direction" do
      old_statement = create(:statement_file, bank_account: bank_account, cutoff_date: 2.months.ago)
      new_statement = create(:statement_file, bank_account: bank_account, cutoff_date: Time.zone.today)

      get "/bank_accounts/#{bank_account.id}/statement_files", params: { sort: { cutoff_date: "asc" } }, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.first["id"]).to eq(old_statement.id)
      expect(json.last["id"]).to eq(new_statement.id)
    end

    it "returns cutoff_date in the response" do
      cutoff_date = Time.zone.today
      statement_file = create(:statement_file, bank_account: bank_account, cutoff_date: cutoff_date)

      get "/bank_accounts/#{bank_account.id}/statement_files", as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.first["cutoff_date"]).to be_present
    end

    it "only returns statement files for the specified bank account" do
      other_bank_account = create(:bank_account, user: user)
      own_statement = create(:statement_file, bank_account: bank_account)
      other_statement = create(:statement_file, bank_account: other_bank_account)

      get "/bank_accounts/#{bank_account.id}/statement_files", as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(own_statement.id)
    end
  end
end
