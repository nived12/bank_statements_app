class CategoriesController < ApplicationController
  before_action :authenticate!
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  # GET /categories
  def index
    @search = params[:search].to_s.strip
    @parents = current_user.categories.where(parent_id: nil)

    if @search.present?
      term = "%#{@search}%"
      @parents = @parents.where(
        "categories.name ILIKE :term OR EXISTS (SELECT 1 FROM categories children WHERE children.parent_id = categories.id AND children.name ILIKE :term)",
        term: term
      )
    end

    @parents = @parents.order(:name)
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

    # Fetch transactions for this category and all its subcategories
    category_ids = [@category.id] + @category.children.pluck(:id)

    # Get all transactions for these categories, sorted by date (most recent first)
    all_transactions = current_user.transactions
                                   .where(category_id: category_ids)
                                   .includes(:bank_account, :category)
                                   .order(date: :desc, created_at: :desc)

    # Paginate with 50 items per page
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    begin
      @pagy, @transactions = pagy(all_transactions, items: 50, page: page)
    rescue Pagy::OverflowError
      # If page is beyond total pages, reset to page 1
      @pagy, @transactions = pagy(all_transactions, items: 50, page: 1)
    end
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
        format.html do
          if @category.parent_id.present?
            redirect_to category_path(@category.parent), notice: t("categories.created")
          else
            redirect_to categories_path, notice: t("categories.created")
          end
        end
        format.turbo_stream do
          # Will render create.turbo_stream.erb which handles both parent and subcategories
        end
      else
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream do
          # Use appropriate modal based on whether it's a subcategory or parent
          modal_id = @category.parent_id.present? ? "subcategory-modal" : "category-modal"
          partial_name = @category.parent_id.present? ? "subcategory_modal" : "category_form"
          render turbo_stream: turbo_stream.replace(
            modal_id,
            partial: partial_name,
            locals: { category: @category }
          )
        end
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
        format.html do
          if @category.parent_id.present?
            # Subcategory - redirect back to parent
            redirect_to category_path(@category.parent), notice: t("categories.updated")
          else
            # Parent category - redirect to index
            redirect_to categories_path, notice: t("categories.updated")
          end
        end
        format.json do
          # Return redirect URL for inline edit
          redirect_url = if @category.parent_id.present?
            category_path(@category.parent)
          else
            categories_path
          end
          render json: { redirect_url: redirect_url }
        end
        format.turbo_stream do
          # Will render update.turbo_stream.erb which handles both parent and subcategories
        end
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @category.errors, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "category-form",
            partial: @category.parent_id.present? ? "subcategory_edit_modal" : "category_form",
            locals: { category: @category }
          )
        end
      end
    end
  end

  # DELETE /categories/:id
  def destroy
    parent_id = @category.parent_id

    # If category has children (subcategories), they will be deleted via dependent: :destroy
    # Nullify category_id for all transactions associated with this category or its children
    # This prevents orphaned transactions and maintains data integrity
    if @category.transactions.exists?
      @category.transactions.update_all(category_id: nil)
    end

    # Also nullify transactions for all subcategories before they are deleted
    @category.children.each do |child|
      child.transactions.update_all(category_id: nil) if child.transactions.exists?
    end

    if @category.destroy
      if parent_id.present?
        redirect_to category_path(parent_id), status: :see_other, notice: t("categories.deleted")
      else
        redirect_to categories_path, status: :see_other, notice: t("categories.deleted")
      end
    else
      # Destruction failed - show error message
      error_message = @category.errors.full_messages.join(", ")
      if parent_id.present?
        redirect_to category_path(parent_id), status: :see_other, alert: error_message
      else
        redirect_to categories_path, status: :see_other, alert: error_message
      end
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
