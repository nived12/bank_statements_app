# frozen_string_literal: true

module Api
  module V1
    class TransactionsController < BaseController
      before_action :set_transaction, only: [:show, :update, :destroy]

      # GET /api/v1/transactions
      def index
        lister_result = load_filtered_transactions
        return if lister_result.nil?

        transactions = lister_result.payload[:transactions]
        calculate_and_assign_stats(transactions)
        @transactions = paginate(transactions)
        @filters = request_params
      end

      # GET /api/v1/transactions/:id
      def show; end

      # POST /api/v1/transactions
      def create
        result = Transactions::CreateService.call(transaction_params)

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
        return unless ensure_manual_transaction("update")

        result = Transactions::UpdateService.call(@transaction.id, transaction_params)

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
        return unless ensure_manual_transaction("delete")

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
        lister_result = load_filtered_transactions
        return if lister_result.nil?

        transactions = lister_result.payload[:transactions]
        calculate_and_assign_stats(transactions)
        @filters = request_params
      end

      private

      def calculate_and_assign_stats(transactions)
        result = Transactions::StatsCalculator.call(transactions)
        @stats = result.payload if result.success?
      end

      def load_filtered_transactions
        result = Transactions::Lister.call(current_user, request_params)

        unless result.success?
          render_error(
            "TRANSACTIONS_LOAD_FAILED",
            message: "Failed to load transactions",
            details: result.errors.full_messages
          )
          return
        end

        result
      end

      def ensure_manual_transaction(action)
        unless @transaction.source == "manual"
          render_error(
            "#{action.upcase}_NOT_ALLOWED",
            message: "Only manual transactions can be #{action}",
            status: :forbidden
          )
          return false
        end
        true
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
