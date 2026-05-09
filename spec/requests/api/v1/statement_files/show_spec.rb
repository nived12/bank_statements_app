# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::StatementFiles - Show", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:auth_headers) do
    {
      "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}"
    }
  end

  describe "GET /api/v1/statement_files/:id" do
    it "returns statement file details" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      get "/api/v1/statement_files/#{statement_file.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"]).to eq(statement_file.id)
      expect(json["data"]["status"]).to be_present
      expect(json["data"]["filename"]).to be_present
      expect(json["data"]["bank_account"]).to be_present
    end

    it "returns 404 for non-existent statement file" do
      get "/api/v1/statement_files/99999", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for other user's statement file" do
      other_bank_account = create(:bank_account, user: other_user)
      other_statement = create(:statement_file, user: other_user, bank_account: other_bank_account)

      get "/api/v1/statement_files/#{other_statement.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      bank_account = create(:bank_account, user: user)
      statement_file = create(:statement_file, user: user, bank_account: bank_account)

      get "/api/v1/statement_files/#{statement_file.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
