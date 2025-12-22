# frozen_string_literal: true

module Api
  module V1
    class TransactionsController < BaseController
      before_action :set_transaction, only: [:show, :update, :destroy]
      before_action :ensure_manual_transaction, only: [:update, :destroy]

      # GET /api/v1/transactions
      def index
        result = Transactions::Lister.call(request_params)

        unless result.success?
          render_error(
            "TRANSACTIONS_LOAD_FAILED",
            message: "Failed to load transactions",
            details: result.errors.full_messages
          )
          return
        end

        transactions = result.payload[:transactions]
        @transactions = paginate(transactions)
        @filters = request_params
      end

      # GET /api/v1/transactions/:id
      def show; end

      # POST /api/v1/transactions
      def create
        result = Transactions::Creator.call(transaction_params)

        if result.success?
          @transaction = result.payload
          @message = "Transaction created successfully"
          render(:show, status: :created)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create transaction",
            status: :unprocessable_entity,
            details: format_validation_errors(result.errors)
          )
        end
      end

      # PATCH /api/v1/transactions/:id
      def update
        result = Transactions::Updater.call(@transaction.id, transaction_params)

        if result.success?
          @transaction = result.payload
          @message = "Transaction updated successfully"
          render(:show, status: :ok)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update transaction",
            status: :unprocessable_entity,
            details: format_validation_errors(result.errors)
          )
        end
      end

      # DELETE /api/v1/transactions/:id
      def destroy
        if @transaction.destroy
          render(json: {
            message: "Transaction deleted successfully"
          }, status: :ok)
        else
          render_error(
            "DELETE_FAILED",
            message: "Failed to delete transaction",
            status: :unprocessable_entity,
            details: format_validation_errors(@transaction.errors)
          )
        end
      end

      # GET /api/v1/transactions/summary
      def summary
        result = Transactions::StatsCalculator.call(request_params)

        if result.success?
          @stats = result.payload
          @filters = request_params
        else
          render_error(
            "STATS_CALCULATION_FAILED",
            message: "Failed to calculate statistics",
            details: result.errors.full_messages
          )
        end
      end

      private

      def ensure_manual_transaction
        return true if @transaction.source == "manual"

        action_verb = action_name == "destroy" ? "deleted" : "updated"
        render_error(
          "#{action_name.upcase}_NOT_ALLOWED",
          message: "Only manual transactions can be #{action_verb}",
          status: :forbidden
        )
        false
      end

      def set_transaction
        @transaction = current_user.transactions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error(
          "TRANSACTION_NOT_FOUND",
          message: "Transaction not found",
          status: :not_found
        )
      end

      def request_params
        params.permit(
          :bank_account_id,
          :statement_file_id,
          :transaction_type,
          :from_date,
          :to_date,
          :sort,
          :direction,
          :search,
          :page,
          :page_token,
          :page_size
        )
      end

      def transaction_params
        permitted = params.require(:transaction).permit(
          :bank_account_id,
          :date,
          :description,
          :amount,
          :transaction_type,
          :merchant,
          :reference,
          :category_id,
          :transfer_account_id,
          saving_ids: [],
          debt_ids: []
        )

        # Sanitize money fields by removing commas and other formatting
        permitted[:amount] = sanitize_money_field(permitted[:amount]) if permitted[:amount].present?

        permitted
      end

      def sanitize_money_field(value)
        value.to_s.delete(",")
      end
    end
  end
end
