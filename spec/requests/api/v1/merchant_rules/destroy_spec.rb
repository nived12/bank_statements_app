# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::MerchantRules - Destroy", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, user: user) }
  let!(:rule) { create(:category_rule, :exact, user: user, category: category, pattern: "Amazon") }

  describe "DELETE /api/v1/merchant_rules/:id" do
    context "when authenticated" do
      it "returns 200 ok" do
        delete "/api/v1/merchant_rules/#{rule.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it "deletes the rule" do
        expect {
          delete "/api/v1/merchant_rules/#{rule.id}", headers: auth_headers
        }.to change(CategoryRule, :count).by(-1)
      end

      it "returns a success message" do
        delete "/api/v1/merchant_rules/#{rule.id}", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["message"]).to be_present
      end

      it "returns 404 for non-existent rule" do
        delete "/api/v1/merchant_rules/99999", headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("MERCHANT_RULE_NOT_FOUND")
      end

      it "cannot delete another user's rule" do
        other_user = create(:user, :confirmed)
        other_cat = create(:category, user: other_user)
        other_rule = create(:category_rule, :exact, user: other_user, category: other_cat, pattern: "Walmart")

        delete "/api/v1/merchant_rules/#{other_rule.id}", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        delete "/api/v1/merchant_rules/#{rule.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
