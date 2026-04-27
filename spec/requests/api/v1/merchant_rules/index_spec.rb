# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::MerchantRules - Index", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, user: user) }

  describe "GET /api/v1/merchant_rules" do
    context "when authenticated" do
      before do
        create(:category_rule, :exact, user: user, category: category, pattern: "Amazon")
        create(:category_rule, :exact, user: user, category: category, pattern: "Walmart")
        create(:category_rule, user: user, category: category, pattern: "super", match_type: "contains")
      end

      it "returns only exact-match active rules" do
        get "/api/v1/merchant_rules", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(2)
        patterns = json["data"].map { |r| r["merchant_name"] }
        expect(patterns).to contain_exactly("Amazon", "Walmart")
      end

      it "includes category data in each rule" do
        get "/api/v1/merchant_rules", headers: auth_headers

        json = JSON.parse(response.body)
        rule = json["data"].first
        expect(rule["category"]).to have_key("id")
        expect(rule["category"]).to have_key("name")
        expect(rule["category"]).to have_key("icon")
      end

      it "includes pagination meta" do
        get "/api/v1/merchant_rules", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["meta"]).to have_key("total_items")
        expect(json["meta"]["total_items"]).to eq(2)
      end

      context "with merchant filter" do
        it "returns matching rule" do
          get "/api/v1/merchant_rules", params: { merchant: "Amazon" }, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["data"].length).to eq(1)
          expect(json["data"].first["merchant_name"]).to eq("Amazon")
        end

        it "returns empty when no match" do
          get "/api/v1/merchant_rules", params: { merchant: "NonExistent" }, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["data"]).to be_empty
        end
      end

      it "does not return other users' rules" do
        other_user = create(:user, :confirmed)
        other_cat = create(:category, user: other_user)
        create(:category_rule, :exact, user: other_user, category: other_cat, pattern: "OtherMerchant")

        get "/api/v1/merchant_rules", headers: auth_headers

        json = JSON.parse(response.body)
        patterns = json["data"].map { |r| r["merchant_name"] }
        expect(patterns).not_to include("OtherMerchant")
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        get "/api/v1/merchant_rules"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
