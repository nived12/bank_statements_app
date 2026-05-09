# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Debts - Destroy", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:debt) { create(:debt, user: user, name: "Credit Card") }

  describe "DELETE /api/v1/debts/:id" do
    it "soft deletes the debt" do
      delete "/api/v1/debts/#{debt.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Debt.kept.find_by(id: debt.id)).to be_nil
      expect(Debt.with_discarded.find_by(id: debt.id)).to be_present
    end

    it "returns 404 for non-existent debt" do
      delete "/api/v1/debts/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's debt" do
      other_user = create(:user)
      other_debt = create(:debt, user: other_user)

      delete "/api/v1/debts/#{other_debt.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/debts/#{debt.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
