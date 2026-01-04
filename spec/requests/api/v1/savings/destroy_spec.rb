# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Savings - Destroy", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:saving) { create(:saving, user: user, name: "Emergency Fund") }

  describe "DELETE /api/v1/savings/:id" do
    it "soft deletes the saving" do
      delete "/api/v1/savings/#{saving.id}", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(Saving.kept.find_by(id: saving.id)).to be_nil
      expect(Saving.with_discarded.find_by(id: saving.id)).to be_present
    end

    it "returns 404 for non-existent saving" do
      delete "/api/v1/savings/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's saving" do
      other_user = create(:user, :confirmed)
      other_saving = create(:saving, user: other_user)

      delete "/api/v1/savings/#{other_saving.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      delete "/api/v1/savings/#{saving.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
