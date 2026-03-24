class CategoryRulesController < ApplicationController
  before_action :set_category_rule, only: [:update, :destroy]

  def index
    @category_rules = current_user.category_rules
                                  .includes(category: :parent)
                                  .order(hits_count: :desc)
    @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)

    respond_to do |format|
      format.html
      format.json
    end
  end

  def create
    @category_rule = current_user.category_rules.new(category_rule_params)
    @category_rule.auto_generated = false

    respond_to do |format|
      if @category_rule.save
        @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)
        format.turbo_stream
        format.html { redirect_to category_rules_path, notice: t("category_rules.created") }
      else
        @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)
        format.turbo_stream { render :create_error, status: :unprocessable_entity }
        format.html { redirect_to category_rules_path, alert: @category_rule.errors.full_messages.join(", ") }
      end
    end
  end

  def update
    attrs = update_params
    attrs = attrs.merge(auto_generated: false) if content_edit?(params[:category_rule])
    respond_to do |format|
      if @category_rule.update(attrs)
        @categories = current_user.categories.where(parent_id: nil).includes(:children).order(:name)
        format.turbo_stream
        format.html { redirect_to category_rules_path, notice: t("category_rules.updated") }
        format.json { render json: { success: true } }
      else
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to category_rules_path, alert: @category_rule.errors.full_messages.join(", ") }
        format.json do
          render json: { error: @category_rule.errors.full_messages.join(", ") }, status: :unprocessable_entity
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

  alias update_params category_rule_params

  def content_edit?(rule_params)
    rule_params&.keys&.any? { |k| %w[pattern match_type category_id].include?(k) }
  end
end
