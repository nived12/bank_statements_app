# frozen_string_literal: true

module Api
  module V1
    class DebtTransactionsController < BaseController
      before_action :set_debt
      before_action :set_transaction, only: [:create]

      # POST /api/v1/debts/:debt_id/transactions
      def create
        amount_applied = params[:amount_applied].to_s.gsub(/[,\s]/, "").to_f
        notes = params[:notes]

        result = Debts::LinkTransactionService.call(
          @debt,
          @transaction,
          amount_applied,
          notes: notes,
          manual: true
        )

        if result.success?
          @debt.reload # Reload to get updated current_balance
          @message = "Transaction linked to debt successfully"
          render("api/v1/debts/show", status: :created)
        else
          render_error(
            "LINK_FAILED",
            message: result.errors.first,
            status: :unprocessable_entity
          )
        end
      end

      # DELETE /api/v1/debts/:debt_id/transactions/:id
      def destroy
        # Find transaction scoped to current user to prevent unauthorized access
        transaction = current_user.transactions.find(params[:id])

        result = Debts::UnlinkTransactionService.call(@debt, transaction)

        if result.success?
          @debt.reload
          @message = "Transaction unlinked from debt successfully"
          render("api/v1/debts/show")
        else
          render_error(
            "UNLINK_FAILED",
            message: result.errors.first,
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_debt
        @debt = current_user.debts.find(params[:debt_id])
      end

      def set_transaction
        @transaction = current_user.transactions.find(params[:transaction_id])
      end
    end
  end
end
