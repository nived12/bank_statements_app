# frozen_string_literal: true

module Api
  module V1
    class DebtsController < BaseController
      include CalculationSettingsTransformable

      before_action :set_debt, only: [:show, :update, :destroy]

      # GET /api/v1/debts
      def index
        debts = current_user.debts.kept
                             .includes(:goals, :categories, :bank_accounts)
                             .order(created_at: :desc)

        # Apply status filter
        if params[:status].present? && params[:status] != "all"
          debts = debts.filter_by_status(params[:status])
        end

        # Apply goal filter and ordering
        debts = debts.filter_by_goal(params[:goal_id]).sort_by_priority if params[:goal_id].present?

        # Paginate
        @debts = paginate(debts)
      end

      # GET /api/v1/debts/:id
      def show; end

      # POST /api/v1/debts
      def create
        result = Debts::Creator.call(debt_params)

        if result.success?
          @debt = result.payload
          @message = "Debt created successfully"
          render(:show, status: :created)
        else
          @debt = result.payload
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create debt",
            status: :unprocessable_content,
            details: format_validation_errors(@debt.errors)
          )
        end
      end

      # PATCH /api/v1/debts/:id
      def update
        result = Debts::Updater.call(@debt, debt_params)

        if result.success?
          @debt = result.payload
          @message = "Debt updated successfully"
          render(:show)
        else
          @debt = result.payload
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update debt",
            status: :unprocessable_content,
            details: format_validation_errors(@debt.errors)
          )
        end
      end

      # DELETE /api/v1/debts/:id
      def destroy
        @debt.discard!
        head(:no_content)
      end

      private

      def set_debt
        @debt = current_user.debts.find(params[:id])
      end

      def debt_params
        permitted_params = params.require(:debt).permit(
          :name,
          :original_amount,
          :current_balance,
          :interest_rate,
          :minimum_payment,
          :auto_sync_transactions,
          :icon,
          :color,
          :status,
          :notes,
          :due_day_of_month,
          :payment_frequency,
          :payment_mode,
          :target_payment_amount,
          :target_payoff_date,
          :calculation_settings_income,
          :calculation_settings_expense,
          :calculation_settings_transfer_in,
          :calculation_settings_transfer_out,
          category_ids: [],
          bank_account_ids: []
        )

        # Use concern method to sanitize money fields
        fields_to_sanitize = %i[original_amount current_balance interest_rate minimum_payment target_payment_amount]
        sanitize_money_fields!(permitted_params, fields_to_sanitize)

        # Use concern method to transform calculation settings
        transform_calculation_settings!(permitted_params)

        # Add user to params
        permitted_params[:user_id] = current_user.id
        permitted_params
      end
    end
  end
end
