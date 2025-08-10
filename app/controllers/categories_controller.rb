class CategoriesController < ApplicationController
  def index
    @parents = current_user.categories.where(parent_id: nil).order(:name)
  end

  def new
    @category = current_user.categories.new
  end

  def create
    @category = current_user.categories.new(category_params)
    if @category.save
      redirect_to "/categories", notice: "Category created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def category_params
    params.require(:category).permit(:name, :parent_id)
  end
end
