# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Categories - Destroy", type: :request do
  let(:user) { create(:user, :consented) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }

  describe "DELETE /api/v1/categories/:id" do
    context "when category has no children" do
      let(:category) { create(:category, user: user, name: "Food") }

      it "deletes category successfully" do
        category_id = category.id
        initial_count = user.categories.count

        delete "/api/v1/categories/#{category_id}", headers: auth_headers

        json = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json["data"]["message"]).to eq(I18n.t("api.categories.destroyed"))
        expect(user.categories.count).to eq(initial_count - 1)
      end

      it "nullifies category_id for associated transactions" do
        bank = create(:bank, name: "Test Bank")
        bank_account = create(:bank_account, user: user, bank: bank)
        transaction = create(:transaction, user: user, bank_account: bank_account, category: category, source: :manual)

        delete "/api/v1/categories/#{category.id}", headers: auth_headers

        transaction.reload
        expect(transaction.category_id).to be_nil
      end
    end

    context "when category has children" do
      let(:parent_category) { create(:category, user: user, name: "Food") }
      let!(:subcategory) { create(:category, user: user, name: "Groceries", parent: parent_category) }

      it "returns error and does not delete category" do
        initial_count = user.categories.count

        delete "/api/v1/categories/#{parent_category.id}", headers: auth_headers

        json = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("DELETE_NOT_ALLOWED")
        expect(json["error"]["message"]).to eq("Cannot delete category with subcategories")
        expect(user.categories.count).to eq(initial_count)
      end
    end

    it "returns 404 for non-existent category" do
      delete "/api/v1/categories/999999", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 when not authenticated" do
      category = create(:category, user: user)
      delete "/api/v1/categories/#{category.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
