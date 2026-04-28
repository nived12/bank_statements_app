class CategoryRulesController < ApplicationController
  before_action :set_category_rule, only: [:update, :destroy]

  # GET /category_rules/lookup?merchant=X
  # Returns the matching exact-match category rule for the given merchant name.
  # Used by the merchant-suggest Stimulus controller to auto-fill the category picker.
  def lookup
    merchant = params[:merchant].to_s.strip
    category_id = nil
    category_name = nil

    if merchant.present?
      rule = current_user.category_rules
                         .active
                         .where(match_type: "exact")
                         .where("LOWER(pattern) = LOWER(?)", merchant)
                         .includes(:category)
                         .first
      if rule
        category_id   = rule.category_id
        category_name = rule.category&.name
      end
    end

    render json: { category_id: category_id, category_name: category_name }
  end

  # POST /category_rules/upsert
  # Creates or updates an exact-match rule for merchant → category.
  # Called silently from the merchant-suggest controller when a user manually picks a category.
  def upsert
    merchant     = params[:merchant].to_s.strip
    category_id  = params[:category_id].to_i

    unless merchant.present? && category_id > 0
      render json: { success: false, error: "Missing merchant or category_id" }, status: :unprocessable_content
      return
    end

    rule = current_user.category_rules.find_or_initialize_by(
      match_type: "exact",
      pattern: merchant
    )
    rule.category_id = category_id
    rule.active      = true

    if rule.save
      render json: { success: true, id: rule.id }
    else
      render json: { success: false, error: rule.errors.full_messages.join(", ") }, status: :unprocessable_content
    end
  end

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
        format.json { render json: { success: true, id: @category_rule.id } }
      else
        load_categories
        format.turbo_stream { render :create_error, status: :unprocessable_content }
        format.html { redirect_to category_rules_path, alert: @category_rule.errors.full_messages.join(", ") }
        format.json { render json: { success: false, error: @category_rule.errors.full_messages.join(", ") }, status: :unprocessable_content }
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
