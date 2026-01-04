# frozen_string_literal: true

module Api
  module V1
    class SavingsController < BaseController
      include CalculationSettingsTransformable

      before_action :set_saving, only: [:show, :update, :destroy]

      # GET /api/v1/savings
      def index
        savings = current_user.savings.kept
                               .includes(:goals, :categories, :bank_accounts)
                               .order(created_at: :desc)

        # Apply status filter
        if params[:status].present? && params[:status] != "all"
          savings = savings.where(status: params[:status])
        end

        # Apply goal filter
        savings = savings.filtered_by_goal(params[:goal_id]) if params[:goal_id].present?

        # Paginate
        @savings = paginate(savings)
      end

      # GET /api/v1/savings/:id
      def show
        # Loads @saving via before_action
      end

      # POST /api/v1/savings
      def create
        result = Savings::CreateService.call(saving_params)

        if result.success?
          @saving = result.payload
          @message = "Saving created successfully"
          render(:show, status: :created)
        else
          @saving = result.payload
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create saving",
            status: :unprocessable_entity,
            details: format_validation_errors(@saving.errors)
          )
        end
      end

      # PATCH /api/v1/savings/:id
      def update
        # Use non-mutating deep_transform_values to avoid modifying original params
        params_hash = saving_params.to_h.deep_transform_values(&:presence)
        category_ids = params_hash.delete(:category_ids)&.reject(&:blank?) || []
        bank_account_ids = params_hash.delete(:bank_account_ids)&.reject(&:blank?) || []

        success = ActiveRecord::Base.transaction do
          # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
          @saving.category_ids = category_ids
          @saving.bank_account_ids = bank_account_ids
          @saving.update(params_hash)
        end

        if success
          @message = "Saving updated successfully"
          render(:show)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update saving",
            status: :unprocessable_entity,
            details: format_validation_errors(@saving.errors)
          )
        end
      end

      # DELETE /api/v1/savings/:id
      def destroy
        @saving.discard!
        head(:no_content)
      end

      private

      def set_saving
        @saving = current_user.savings.find(params[:id])
      end

      def saving_params
        permitted = params.require(:saving).permit(
          :name,
          :target_amount,
          :current_amount,
          :target_date,
          :auto_sync_transactions,
          :icon,
          :color,
          :status,
          :notes,
          # Contribution tracking fields
          :target_contribution_amount,
          :contribution_frequency,
          :contribution_mode,
          # Calculation settings
          :calculation_settings_income,
          :calculation_settings_expense,
          :calculation_settings_transfer_in,
          :calculation_settings_transfer_out,
          # Multi-select arrays
          category_ids: [],
          bank_account_ids: []
        )

        # Use concern method to sanitize money fields
        sanitize_money_fields!(permitted, :target_amount, :current_amount, :target_contribution_amount)

        # Use concern method to transform calculation settings
        transform_calculation_settings!(permitted)

        # Add user to params
        permitted[:user_id] = current_user.id

        permitted
      end
    end
  end
end
