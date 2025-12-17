# frozen_string_literal: true

module Api
  module V1
    class TransactionsController < BaseController
      before_action :set_transaction, only: [:show, :update, :destroy]

      # GET /api/v1/transactions
      def index
        result = Transactions::Lister.call(current_user, request_params)

        if result.success?
          transactions = result.payload[:transactions]

          # Calculate stats before pagination (needs full filtered set)
          stats_result = Transactions::StatsCalculator.call(transactions)
          @stats = stats_result.payload if stats_result.success?

          # Paginate using BaseController helper
          @transactions = paginate(transactions)

          @filters = request_params
          # Rails will implicitly render index.json.jbuilder
        else
          render_error(
            "TRANSACTIONS_LOAD_FAILED",
            message: "Failed to load transactions",
            details: result.errors.full_messages
          )
        end
      end

      # GET /api/v1/transactions/:id
      def show
        # @transaction is set by before_action
        # Rails will implicitly render show.json.jbuilder
      end

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
        # Only allow updating manual transactions
        unless @transaction.source == "manual"
          return render_error(
            "UPDATE_NOT_ALLOWED",
            message: "Only manual transactions can be updated",
            status: :forbidden
          )
        end

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
        # Only allow deletion of manual transactions
        unless @transaction.source == "manual"
          return render_error(
            "DELETE_NOT_ALLOWED",
            message: "Only manual transactions can be deleted",
            status: :forbidden
          )
        end

        if @transaction.destroy
          render(json: {
            message: "Transaction deleted successfully"
          }, status: :ok)
        else
          render_error(
            "DELETE_FAILED",
            message: "Failed to delete transaction",
            status: :unprocessable_entity,
            details: @transaction.errors.full_messages
          )
        end
      end

      # GET /api/v1/transactions/summary
      def summary
        result = Transactions::Lister.call(current_user, request_params)

        if result.success?
          transactions = result.payload[:transactions]

          # Calculate stats using service
          stats_result = Transactions::StatsCalculator.call(transactions)
          @stats = stats_result.payload if stats_result.success?

          @filters = request_params
          # Rails will implicitly render summary.json.jbuilder
        else
          render_error(
            "SUMMARY_LOAD_FAILED",
            message: "Failed to load transaction summary",
            details: result.errors.full_messages
          )
        end
      end

      private

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
