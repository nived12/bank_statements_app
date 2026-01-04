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

        result = Savings::LinkTransactionService.call(
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
            message: result.errors.first,
            status: :unprocessable_entity
          )
        end
      end

      # DELETE /api/v1/savings/:saving_id/transactions/:id
      def destroy
        transaction = Transaction.find(params[:id])

        # Verify the transaction belongs to the user
        unless transaction.user_id == current_user.id
          return render_error(
            "UNAUTHORIZED",
            message: "You do not have permission to access this transaction",
            status: :forbidden
          )
        end

        result = Savings::UnlinkTransactionService.call(@saving, transaction)

        if result.success?
          @saving.reload
          @message = "Transaction unlinked from saving successfully"
          render("api/v1/savings/show")
        else
          render_error(
            "UNLINK_FAILED",
            message: result.errors.first,
            status: :unprocessable_entity
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
