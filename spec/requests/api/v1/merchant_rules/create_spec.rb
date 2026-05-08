# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::MerchantRules - Create", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, user: user) }

  describe "POST /api/v1/merchant_rules" do
    context "when authenticated" do
      context "with valid params" do
        let(:valid_params) do
          {
            merchant_rule: {
              merchant_name: "Amazon",
              category_id: category.id
            }
          }
        end

        it "returns 201 created" do
          post "/api/v1/merchant_rules", params: valid_params, headers: auth_headers

          expect(response).to have_http_status(:created)
        end

        it "creates a CategoryRule with exact match" do
          expect {
            post "/api/v1/merchant_rules", params: valid_params, headers: auth_headers
          }.to change(CategoryRule, :count).by(1)

          rule = CategoryRule.last
          expect(rule.pattern).to eq("Amazon")
          expect(rule.match_type).to eq("exact")
          expect(rule.category_id).to eq(category.id)
          expect(rule.user_id).to eq(user.id)
        end

        it "returns the created rule data" do
          post "/api/v1/merchant_rules", params: valid_params, headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["data"]["merchant_name"]).to eq("Amazon")
          expect(json["data"]["category"]["id"]).to eq(category.id)
        end
      end

      context "upsert behavior (same merchant_name)" do
        let!(:existing_rule) do
          create(:category_rule, :exact, user: user, category: category, pattern: "Amazon")
        end
        let(:other_category) { create(:category, user: user) }

        it "returns 200 ok (not 201) for update" do
          post "/api/v1/merchant_rules",
            params: { merchant_rule: { merchant_name: "Amazon", category_id: other_category.id } },
            headers: auth_headers

          expect(response).to have_http_status(:ok)
        end

        it "updates the category without creating a duplicate" do
          expect {
            post "/api/v1/merchant_rules",
              params: { merchant_rule: { merchant_name: "Amazon", category_id: other_category.id } },
              headers: auth_headers
          }.not_to change(CategoryRule, :count)

          existing_rule.reload
          expect(existing_rule.category_id).to eq(other_category.id)
        end
      end

      context "with blank merchant_name" do
        it "returns 422 unprocessable entity" do
          post "/api/v1/merchant_rules",
            params: { merchant_rule: { merchant_name: "", category_id: category.id } },
            headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        end
      end

      context "with missing merchant_rule param" do
        it "returns 400 bad request" do
          post "/api/v1/merchant_rules", params: {}, headers: auth_headers

          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context "when not authenticated" do
      it "returns 401 unauthorized" do
        post "/api/v1/merchant_rules",
          params: { merchant_rule: { merchant_name: "Amazon", category_id: 1 } }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
