# frozen_string_literal: true

module Api
  module V1
    class BankAccountsController < BaseController
      before_action :set_bank_account, only: [:show, :update, :destroy]

      # GET /api/v1/bank_accounts
      def index
        @bank_accounts = current_user.bank_accounts
                                     .includes(:bank)
                                     .order(:custom_name, :account_number)
      end

      # GET /api/v1/bank_accounts/:id
      def show; end

      # POST /api/v1/bank_accounts
      def create
        @bank_account = current_user.bank_accounts.new(bank_account_params)

        if @bank_account.save
          @message = "Bank account created successfully"
          render(:show, status: :created)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create bank account",
            status: :unprocessable_content,
            details: format_validation_errors(@bank_account.errors)
          )
        end
      end

      # PATCH /api/v1/bank_accounts/:id
      def update
        if @bank_account.update(bank_account_params)
          @message = "Bank account updated successfully"
          render(:show, status: :ok)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update bank account",
            status: :unprocessable_content,
            details: format_validation_errors(@bank_account.errors)
          )
        end
      end

      # DELETE /api/v1/bank_accounts/:id
      def destroy
        @bank_account.destroy
        head(:no_content)
      end

      private

      def set_bank_account
        @bank_account = current_user.bank_accounts.find(params[:id])
      end

      def bank_account_params
        params.require(:bank_account).permit(
          :bank_id,
          :account_number,
          :custom_name,
          :currency,
          :opening_balance,
          :opening_balance_date,
          :account_type
        )
      end
    end
  end
end
