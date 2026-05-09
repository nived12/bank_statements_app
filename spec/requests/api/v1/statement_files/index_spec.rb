# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Index", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:auth_headers) do
    {
      "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}"
    }
  end

  describe "GET /api/v1/statement_files" do
    it "returns list of statement files" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      get "/api/v1/statement_files", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["statement_files"]).to be_an(Array)
      expect(json["data"]["statement_files"].length).to eq(1)
      expect(json["data"]["statement_files"][0]["id"]).to eq(statement_file.id)
    end

    it "returns empty array when no statement files exist" do
      get "/api/v1/statement_files", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["statement_files"]).to eq([])
    end

    it "supports pagination with page parameter" do
      bank_account = create(:bank_account, user: user)
      create_list(:statement_file, 25, user: user, bank_account: bank_account)

      get "/api/v1/statement_files?page=2", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["statement_files"].length).to eq(5)
      expect(json["meta"]["pagination"]["current_page"]).to eq(2)
    end

    it "supports pagination with page_size parameter" do
      bank_account = create(:bank_account, user: user)
      create_list(:statement_file, 15, user: user, bank_account: bank_account)

      get "/api/v1/statement_files?page_size=5", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["statement_files"].length).to eq(5)
      expect(json["meta"]["pagination"]["page_size"]).to eq(5)
      expect(json["meta"]["pagination"]["total_items"]).to eq(15)
    end

    it "includes bank_account data" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      get "/api/v1/statement_files", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      statement = json["data"]["statement_files"][0]
      expect(statement["bank_account"]).to be_present
      expect(statement["bank_account"]["id"]).to eq(bank_account.id)
      expect(statement["bank_account"]["display_name"]).to be_present
    end

    it "orders by cutoff_date DESC" do
      bank_account = create(:bank_account, user: user)
      old_statement = create(:statement_file, user: user, bank_account: bank_account, cutoff_date: 2.days.ago)
      new_statement = create(:statement_file, user: user, bank_account: bank_account, cutoff_date: 1.day.ago)
      middle_statement = create(:statement_file, user: user, bank_account: bank_account, cutoff_date: 1.5.days.ago)

      get "/api/v1/statement_files", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      ids = json["data"]["statement_files"].map { |s| s["id"] }
      expect(ids.first).to eq(new_statement.id)
      expect(ids.second).to eq(middle_statement.id)
      expect(ids.third).to eq(old_statement.id)
    end

    it "does not include other users' statement files" do
      bank_account = create(:bank_account, user: user)
      other_bank_account = create(:bank_account, user: other_user)
      my_statement = create(:statement_file, user: user, bank_account: bank_account)
      other_statement = create(:statement_file, user: other_user, bank_account: other_bank_account)

      get "/api/v1/statement_files", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      ids = json["data"]["statement_files"].map { |s| s["id"] }
      expect(ids).to include(my_statement.id)
      expect(ids).not_to include(other_statement.id)
    end

    it "returns 401 when not authenticated" do
      get "/api/v1/statement_files"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
