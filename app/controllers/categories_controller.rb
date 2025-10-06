class CategoriesController < ApplicationController
  before_action :authenticate!
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  # GET /categories
  def index
    @parents = current_user.categories.where(parent_id: nil).order(:name)
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
        format.html { redirect_to categories_path, notice: t("categories.created") }
        format.turbo_stream {
          # Use redirect with allow_other_host to break out of turbo-frame
          redirect_to categories_path, status: :see_other
        }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("category-modal",
            partial: "category_form",
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
          if @category.parent_id.present?
            # Subcategory update - redirect back to parent category
            redirect_to category_path(@category.parent), status: :see_other
          else
            # Parent category update - redirect to categories list
            redirect_to categories_path, status: :see_other
          end
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
    # Check if category has transactions
    if @category.transactions.exists?
      respond_to do |format|
        format.html { redirect_to categories_path, alert: t("categories.cannot_delete_with_transactions") }
        format.turbo_stream {
          render turbo_stream: turbo_stream.append("flash-messages",
            html: "<div class='alert alert-error'>#{t('categories.cannot_delete_with_transactions')}</div>")
        }
      end
      return
    end

    # Check if category has children
    if @category.children.exists?
      respond_to do |format|
        format.html { redirect_to categories_path, alert: t("categories.cannot_delete_with_subcategories") }
        format.turbo_stream {
          render turbo_stream: turbo_stream.append("flash-messages",
            html: "<div class='alert alert-error'>#{t('categories.cannot_delete_with_subcategories')}</div>")
        }
      end
      return
    end

    parent_id = @category.parent_id
    @category.destroy

    respond_to do |format|
      format.html {
        if parent_id.present?
          redirect_to category_path(parent_id), notice: t("categories.deleted")
        else
          redirect_to categories_path, notice: t("categories.deleted")
        end
      }
      format.turbo_stream {
        if parent_id.present?
          # Subcategory deleted - remove from list and close modal
          render turbo_stream: [
            turbo_stream.remove("subcategory-#{@category.id}"),
            turbo_stream.remove("subcategory-edit-modal")
          ]
        else
          # Parent category deleted - redirect to categories list to see updated list
          render turbo_stream: turbo_stream.action(:redirect, categories_path)
        end
      }
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
