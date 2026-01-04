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
          debts = debts.where(status: params[:status])
        end

        # Apply goal filter and ordering
        if params[:goal_id].present?
          debts = debts.filtered_by_goal(params[:goal_id])
          debts = debts.ordered_by_priority(params[:goal_id])
        end

        # Paginate
        @debts = paginate(debts)
      end

      # GET /api/v1/debts/:id
      def show
        # Loads @debt via before_action
        # Generate payment schedule in controller to avoid computation during view rendering
        if @debt.interest_rate.present? && @debt.target_payment_amount.present?
          @payment_schedule = @debt.generate_payment_schedule(6)
        end
      end

      # POST /api/v1/debts
      def create
        result = Debts::CreateService.call(debt_params)

        if result.success?
          @debt = result.payload
          @message = "Debt created successfully"
          render(:show, status: :created)
        else
          @debt = result.payload
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create debt",
            status: :unprocessable_entity,
            details: format_validation_errors(@debt.errors)
          )
        end
      end

      # PATCH /api/v1/debts/:id
      def update
        # Use non-mutating deep_transform_values to avoid modifying original params
        params_hash = debt_params.to_h.deep_transform_values(&:presence)
        category_ids = params_hash.delete(:category_ids)&.reject(&:blank?) || []
        bank_account_ids = params_hash.delete(:bank_account_ids)&.reject(&:blank?) || []

        success = ActiveRecord::Base.transaction do
          # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
          @debt.category_ids = category_ids
          @debt.bank_account_ids = bank_account_ids
          @debt.update(params_hash)
        end

        if success
          @message = "Debt updated successfully"
          render(:show)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update debt",
            status: :unprocessable_entity,
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
        permitted = params.require(:debt).permit(
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
        sanitize_money_fields!(permitted, :original_amount, :current_balance, :interest_rate, :minimum_payment, :target_payment_amount)

        # Use concern method to transform calculation settings
        transform_calculation_settings!(permitted)

        # Add user to params
        permitted.merge(user_id: current_user.id)
      end
    end
  end
end
