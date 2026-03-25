class CategoryRulesController < ApplicationController
  before_action :set_category_rule, only: [:update, :destroy]

  def index
    @category_rules = current_user.category_rules.includes(category: :parent).order(hits_count: :desc)
    load_categories

    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @category_rule = current_user.category_rules.new(category_rule_params)

    respond_to do |format|
      if @category_rule.save
        load_categories
        format.turbo_stream
        format.html { redirect_to category_rules_path, notice: t("category_rules.created") }
      else
        load_categories
        format.turbo_stream { render :create_error, status: :unprocessable_content }
        format.html { redirect_to category_rules_path, alert: @category_rule.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    respond_to do |format|
      if @category_rule.update(update_params)
        load_categories
        format.turbo_stream
        format.html { redirect_to category_rules_path, notice: t("category_rules.updated") }
        format.json { render json: { success: true } }
      else
        format.turbo_stream { head :unprocessable_content }
        format.html { redirect_to category_rules_path, alert: @category_rule.errors.full_messages.join(", ") }
        format.json do
          render json: { error: @category_rule.errors.full_messages.join(", ") }, status: :unprocessable_content
        end
      end
    end
  end

  def destroy
    @category_rule.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to category_rules_path, notice: t("category_rules.deleted") }
    end
  end

  private

  def set_category_rule
    @category_rule = current_user.category_rules.find(params[:id])
  end

  def category_rule_params
    params.require(:category_rule).permit(:category_id, :match_type, :pattern, :priority, :active)
  end

  def load_categories
    @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)
  end

  alias update_params category_rule_params
end
