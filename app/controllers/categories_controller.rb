class CategoriesController < ApplicationController
  before_action :authenticate!
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  # GET /categories
  def index
    @parents = current_user.categories.where(parent_id: nil).order(:name)
    @categories = current_user.categories.order(:name)

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /categories/:id
  def show
    # @category is set by before_action
    # Show parent category with its subcategories
  end

  # GET /categories/new
  def new
    @category = current_user.categories.new
    @category.parent_id = params[:parent_id] if params[:parent_id].present?
    @parents = current_user.categories.where(parent_id: nil).order(:name)
  end

  # POST /categories
  def create
    @category = current_user.categories.new(category_params)

    respond_to do |format|
      if @category.save
        format.html {
          if @category.parent_id.present?
            redirect_to category_path(@category.parent), notice: t("categories.created")
          else
            redirect_to categories_path, notice: t("categories.created")
          end
        }
        format.turbo_stream {
          # Will render create.turbo_stream.erb which handles both parent and subcategories
        }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream {
          # Use appropriate modal based on whether it's a subcategory or parent
          modal_id = @category.parent_id.present? ? "subcategory-modal" : "category-modal"
          partial_name = @category.parent_id.present? ? "subcategory_modal" : "category_form"
          render turbo_stream: turbo_stream.replace(modal_id,
            partial: partial_name,
            locals: { category: @category })
        }
      end
    end
  end

  # GET /categories/:id/edit
  def edit
    # @category is set by before_action
    @parents = current_user.categories.where(parent_id: nil).where.not(id: @category.id).order(:name)
  end

  # PATCH /categories/:id
  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html {
          if @category.parent_id.present?
            # Subcategory - redirect back to parent
            redirect_to category_path(@category.parent), notice: t("categories.updated")
          else
            # Parent category - redirect to index
            redirect_to categories_path, notice: t("categories.updated")
          end
        }
        format.json { head :ok }
        format.turbo_stream {
          # Will render update.turbo_stream.erb which handles both parent and subcategories
        }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("category-form",
            partial: @category.parent_id.present? ? "subcategory_edit_modal" : "category_form",
            locals: { category: @category })
        }
      end
    end
  end

  # DELETE /categories/:id
  def destroy
    parent_id = @category.parent_id

    # If category has children (subcategories), they will be deleted via dependent: :destroy
    # If category or its children have transactions, set their category_id to nil
    if @category.transactions.exists?
      @category.transactions.update_all(category_id: nil)
    end

    # Also nullify transactions for all subcategories
    @category.children.each do |child|
      child.transactions.update_all(category_id: nil) if child.transactions.exists?
    end

    @category.destroy

    if parent_id.present?
      redirect_to category_path(parent_id), status: :see_other, notice: t("categories.deleted")
    else
      redirect_to categories_path, status: :see_other, notice: t("categories.deleted")
    end
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :parent_id, :icon)
  end
end
