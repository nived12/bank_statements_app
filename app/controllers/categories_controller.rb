class CategoriesController < ApplicationController
  before_action :authenticate!
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def index
    @parents = current_user.categories.where(parent_id: nil).order(:name)
  end

  def new
    @category = current_user.categories.new
  end

  def create
    @category = current_user.categories.new(category_params)
    if @category.save
      redirect_to categories_path, notice: t("categories.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    # @category is set by before_action
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: t("categories.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    category_name = @category.name

    # Check if category has transactions
    if @category.transactions.exists?
      redirect_to categories_path, alert: t("categories.cannot_delete_with_transactions")
      return
    end

    # Check if category has children
    if @category.children.exists?
      redirect_to categories_path, alert: t("categories.cannot_delete_with_subcategories")
      return
    end

    @category.destroy
    redirect_to categories_path, notice: t("categories.deleted")
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :parent_id)
  end
end
