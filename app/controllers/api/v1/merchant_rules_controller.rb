# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::MerchantRulesController
    # Exposes per-user merchant→category auto-categorization rules.
    # Backed by the existing CategoryRule model (exact match type only).
    #
    # Endpoints:
    # - GET    /api/v1/merchant_rules            — list all rules (optional ?merchant= filter)
    # - POST   /api/v1/merchant_rules            — upsert by merchant_name
    # - DELETE /api/v1/merchant_rules/:id        — delete a rule
    #
    class MerchantRulesController < BaseController
      before_action :set_rule, only: [:destroy]

      # GET /api/v1/merchant_rules
      def index
        rules = current_user.category_rules
                            .exact
                            .active
                            .includes(:category)
                            .by_priority

        rules = rules.where("LOWER(pattern) = LOWER(?)", params[:merchant].to_s.strip) if params[:merchant].present?

        @rules = paginate(rules)
      end

      # POST /api/v1/merchant_rules
      def create
        merchant_name = merchant_rule_params[:merchant_name].to_s.strip

        if merchant_name.blank?
          render_error(
            "VALIDATION_ERROR",
            message: "Merchant name is required",
            status: :unprocessable_content,
            details: [{ field: "merchant_name", message: "can't be blank" }]
          )
          return
        end

        rule = current_user.category_rules.find_or_initialize_by(
          pattern: merchant_name,
          match_type: "exact"
        )
        rule.category_id = merchant_rule_params[:category_id]
        rule.active = true

        if rule.save
          @rule = rule
          render :show, status: rule.previously_new_record? ? :created : :ok
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Merchant rule could not be saved",
            status: :unprocessable_content,
            details: format_validation_errors(rule.errors)
          )
        end
      end

      # DELETE /api/v1/merchant_rules/:id
      def destroy
        @rule.destroy
        render(json: { data: { message: I18n.t("api.merchant_rules.destroyed") } }, status: :ok)
      end

      private

      def set_rule
        @rule = current_user.category_rules.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error("MERCHANT_RULE_NOT_FOUND", message: "Merchant rule not found", status: :not_found)
      end

      def merchant_rule_params
        params.require(:merchant_rule).permit(:merchant_name, :category_id)
      end
    end
  end
end
