require 'rails_helper'

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user, :confirmed) }
  let(:category) { create(:category, user: user) }
  let(:valid_attributes) { { name: "New Category" } }
  let(:invalid_attributes) { { name: "" } }

  before do
    sign_in_user user
  end

  describe "GET /categories" do
    it "returns success" do
      get categories_path
      expect(response).to be_successful
    end

    context "with search param" do
      let!(:parent) { user.categories.find_by!(name: "Ahorros e Inversiones", parent_id: nil) }
      let!(:child) { user.categories.find_by!(name: "Fondo de Vacaciones") }
      let!(:other_parent) { user.categories.find_by!(name: "Comida", parent_id: nil) }

      it "returns matching parent when subcategory name matches" do
        get categories_path, params: { search: "Fondo de Vacaciones" }
        expect(response).to be_successful
        expect(response.body).to include("Ahorros e Inversiones")
        expect(response.body).not_to include("Comida")
      end

      it "returns matching parent when parent name matches" do
        get categories_path, params: { search: "Ahorros" }
        expect(response).to be_successful
        expect(response.body).to include("Ahorros e Inversiones")
        expect(response.body).not_to include("Comida")
      end

      it "returns empty results for unmatched search" do
        get categories_path, params: { search: "zzz_no_match" }
        expect(response).to be_successful
        expect(response.body).not_to include("Ahorros e Inversiones")
        expect(response.body).not_to include("Comida")
      end

      it "does not include another user's subcategories in search results" do
        other_user = create(:user, :confirmed)
        other_parent = create(:category, user: other_user, name: "Otros Ahorros")
        create(:category, user: other_user, name: "Fondo de Vacaciones", parent: other_parent)

        get categories_path, params: { search: "Fondo de Vacaciones" }
        expect(response.body).to include("Ahorros e Inversiones")
        expect(response.body).not_to include("Otros Ahorros")
      end

      it "returns all categories when search is blank" do
        get categories_path, params: { search: "" }
        expect(response.body).to include("Ahorros e Inversiones")
        expect(response.body).to include("Comida")
      end
    end
  end

  describe "GET /categories/:id" do
    it "returns success for user's category" do
      get "/categories/#{category.id}"
      expect(response).to be_successful
    end

    context "when accessing another user's category" do
      let(:other_user) { create(:user) }
      let(:other_category) { create(:category, user: other_user) }

      it "denies access" do
        get "/categories/#{other_category.id}"
        expect(response).not_to be_successful
      end
    end
  end

  describe "GET /categories/new" do
    it "returns success" do
      get "/categories/new"
      expect(response).to be_successful
    end
  end

  describe "POST /categories" do
    context "with valid parameters" do
      it "creates a new category" do
        expect {
          post "/categories", params: { category: valid_attributes }
        }.to change(Category, :count).by(1)
      end

      it "redirects to categories index" do
        post "/categories", params: { category: valid_attributes }
        expect(response).to have_http_status(:redirect)
      end

      it "sets success flash message" do
        post "/categories", params: { category: valid_attributes }
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      it "does not create a new category" do
        expect {
          post categories_path, params: { category: invalid_attributes }
        }.not_to change(Category, :count)
      end

      it "returns unprocessable entity status" do
        post categories_path, params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "GET /categories/:id/edit" do
    it "returns success" do
      get "/categories/#{category.id}/edit"
      expect(response).to be_successful
    end
  end

  describe "PATCH /categories/:id" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Category" } }

      it "updates the category" do
        patch "/categories/#{category.id}", params: { category: new_attributes }
        category.reload
        expect(category.name).to eq("Updated Category")
      end

      it "redirects to categories index" do
        patch "/categories/#{category.id}", params: { category: new_attributes }
        expect(response).to redirect_to(categories_path)
      end
    end

    context "with invalid parameters" do
      it "does not update the category" do
        original_name = category.name
        patch category_path(category), params: { category: invalid_attributes }
        category.reload
        expect(category.name).to eq(original_name)
      end

      it "returns unprocessable entity" do
        patch category_path(category), params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /categories/:id" do
    it "destroys the category" do
      category_to_delete = category
      expect {
        delete "/categories/#{category_to_delete.id}"
      }.to change(Category, :count).by(-1)
    end

    it "redirects to categories index" do
      delete "/categories/#{category.id}"
      expect(response).to redirect_to(categories_path)
    end

    context "when category has subcategories" do
      let!(:subcategory) { create(:category, user: user, parent: category) }

      it "prevents deletion of category with subcategories" do
        expect {
          delete "/categories/#{category.id}"
        }.not_to change(Category, :count)

        expect(response).to redirect_to(categories_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when category has transactions" do
      let!(:bank_account) { create(:bank_account, user: user) }
      let!(:transaction) { create(:transaction, user: user, category: category, bank_account: bank_account) }

      it "deletes category and nullifies transactions" do
        transaction_id = transaction.id
        expect {
          delete "/categories/#{category.id}"
        }.to change(Category, :count).by(-1)

        expect(Transaction.find(transaction_id).category_id).to be_nil
      end
    end
  end
end
