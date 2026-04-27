# frozen_string_literal: true

module Api
  module V1
    class CategoriesController < BaseController
      before_action :require_confirmed_user!, only: %i[create update destroy]
      before_action :set_category, only: [:show, :update, :destroy]

      # GET /api/v1/categories
      def index
        categories = current_user.categories
                                 .where(parent_id: nil)
                                 .includes(:transactions, children: :transactions)
                                 .order(:name)
        @categories = paginate(categories)
      end

      # GET /api/v1/categories/:id
      def show; end

      # POST /api/v1/categories
      def create
        @category = current_user.categories.new(category_params)

        if @category.save
          @message = "Category created successfully"
          render(:show, status: :created)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create category",
            status: :unprocessable_content,
            details: format_validation_errors(@category.errors)
          )
        end
      end

      # PATCH /api/v1/categories/:id
      def update
        if @category.update(category_params)
          @message = "Category updated successfully"
          render(:show, status: :ok)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update category",
            status: :unprocessable_content,
            details: format_validation_errors(@category.errors)
          )
        end
      end

      # DELETE /api/v1/categories/:id
      def destroy
        if @category.children.any?
          render_error(
            "DELETE_NOT_ALLOWED",
            message: "Cannot delete category with subcategories",
            status: :unprocessable_content
          )
          return
        end

        @category.transactions.update_all(category_id: nil)

        if @category.destroy
          render(json: { data: { message: I18n.t("api.categories.destroyed") } }, status: :ok)
        else
          render_error(
            "DELETE_FAILED",
            message: "Failed to delete category",
            status: :unprocessable_content,
            details: format_validation_errors(@category.errors)
          )
        end
      end

      private

      def set_category
        @category = current_user.categories
                                .includes(:transactions, children: :transactions)
                                .find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error(
          "CATEGORY_NOT_FOUND",
          message: "Category not found",
          status: :not_found
        )
      end

      def category_params
        params.require(:category).permit(:name, :icon, :color, :parent_id)
      end
    end
  end
end
