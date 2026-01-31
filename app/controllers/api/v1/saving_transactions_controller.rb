# frozen_string_literal: true

module Api
  module V1
    class SavingTransactionsController < BaseController
      before_action :set_saving
      before_action :set_transaction, only: [:create]

      # POST /api/v1/savings/:saving_id/transactions
      def create
        amount_applied = params[:amount_applied].to_s.gsub(/[,\s]/, "").to_f
        notes = params[:notes]

        result = Savings::TransactionLinker.call(
          @saving,
          @transaction,
          amount_applied,
          notes: notes,
          manual: true
        )

        if result.success?
          @saving.reload # Reload to get updated current_amount
          @message = "Transaction linked to saving successfully"
          render("api/v1/savings/show", status: :created)
        else
          render_error(
            "LINK_FAILED",
            message: "Failed to link transaction to saving",
            status: :unprocessable_content,
            details: result.errors.to_a
          )
        end
      end

      # DELETE /api/v1/savings/:saving_id/transactions/:id
      def destroy
        # Find transaction scoped to current user to prevent unauthorized access
        transaction = current_user.transactions.find(params[:id])

        result = Savings::TransactionUnlinker.call(@saving, transaction)

        if result.success?
          @saving.reload
          @message = "Transaction unlinked from saving successfully"
          render("api/v1/savings/show")
        else
          render_error(
            "UNLINK_FAILED",
            message: "Failed to unlink transaction from saving",
            status: :unprocessable_content,
            details: result.errors.to_a
          )
        end
      end

      private

      def set_saving
        @saving = current_user.savings.find(params[:saving_id])
      end

      def set_transaction
        @transaction = current_user.transactions.find(params[:transaction_id])
      end
    end
  end
end
