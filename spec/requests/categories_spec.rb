require 'rails_helper'

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:valid_attributes) { { name: "New Category" } }
  let(:invalid_attributes) { { name: "" } }

  before do
    sign_in user
  end

  describe "GET /categories" do
    it "displays the categories index" do
      get categories_path
      expect(response).to be_successful
      expect(response.body).to include(I18n.t('categories.manage'))
      expect(response.body).to include(I18n.t('categories.organize_spending'))
    end

    it "shows empty state when no categories exist" do
      get categories_path
      expect(response.body).to include(I18n.t('categories.no_categories_yet'))
      expect(response.body).to include(I18n.t('categories.create_first_description'))
    end

    it "shows categories when they exist" do
      category
      get categories_path
      expect(response.body).to include(category.name)
    end
  end

  describe "GET /categories/new" do
    it "displays the new category form" do
      get new_category_path
      expect(response).to be_successful
      expect(response.body).to include(I18n.t('categories.new'))
      expect(response.body).to include(I18n.t('categories.add_new_description'))
    end
  end

  describe "POST /categories" do
    context "with valid parameters" do
      it "creates a new category" do
        expect {
          post categories_path, params: { category: valid_attributes }
        }.to change(Category, :count).by(1)
      end

      it "redirects to the categories index with success message" do
        post categories_path, params: { category: valid_attributes }
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include(I18n.t('categories.created'))
      end
    end

    context "with invalid parameters" do
      it "does not create a new category" do
        expect {
          post categories_path, params: { category: invalid_attributes }
        }.not_to change(Category, :count)
      end

      it "re-renders the new template with errors" do
        post categories_path, params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t('categories.new'))
      end
    end
  end

  describe "GET /categories/:id/edit" do
    it "displays the edit category form" do
      get edit_category_path(category)
      expect(response).to be_successful
      expect(response.body).to include(I18n.t('categories.edit'))
      expect(response.body).to include(I18n.t('categories.modify_description', name: category.name))
    end
  end

  describe "PATCH /categories/:id" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Category" } }

      it "updates the requested category" do
        patch category_path(category), params: { category: new_attributes }
        category.reload
        expect(category.name).to eq("Updated Category")
      end

      it "redirects to the categories index with success message" do
        patch category_path(category), params: { category: new_attributes }
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include(I18n.t('categories.updated'))
      end
    end

    context "with invalid parameters" do
      it "does not update the category" do
        original_name = category.name
        patch category_path(category), params: { category: invalid_attributes }
        category.reload
        expect(category.name).to eq(original_name)
      end

      it "re-renders the edit template with errors" do
        patch category_path(category), params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t('categories.edit'))
      end
    end
  end

  describe "DELETE /categories/:id" do
    it "destroys the requested category" do
      category_to_delete = category
      expect {
        delete category_path(category_to_delete)
      }.to change(Category, :count).by(-1)
    end

    it "redirects to the categories index with success message" do
      delete category_path(category)
      expect(response).to redirect_to(categories_path)
      follow_redirect!
      expect(response.body).to include(I18n.t('categories.deleted'))
    end

    context "when category has subcategories" do
      let!(:subcategory) { create(:category, user: user, parent: category) }

      it "prevents deletion and shows error message" do
        delete category_path(category)
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include(I18n.t('categories.cannot_delete_with_subcategories'))
      end
    end

    context "when category has transactions" do
      let!(:transaction) { create(:transaction, user: user, category: category) }

      it "prevents deletion and shows error message" do
        delete category_path(category)
        expect(response).to redirect_to(categories_path)
        follow_redirect!
        expect(response.body).to include(I18n.t('categories.cannot_delete_with_transactions'))
      end
    end
  end
end
