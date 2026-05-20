# frozen_string_literal: true

module Api
  module V1
    class TransactionsController < BaseController
      before_action :require_confirmed_user!, only: %i[create update destroy]
      before_action :set_transaction, only: [:show, :update, :destroy]
      before_action :ensure_manual_transaction, only: [:update, :destroy]
      before_action :check_ai_subscription!, only: [:parse_voice, :parse_image, :recurring_suggestions]

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
            status: :unprocessable_content,
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
            status: :unprocessable_content,
            details: format_validation_errors(result.errors)
          )
        end
      end

      # DELETE /api/v1/transactions/:id
      def destroy
        if @transaction.destroy
          render(json: { data: { message: I18n.t("api.transactions.destroyed") } }, status: :ok)
        else
          render_error(
            "DELETE_FAILED",
            message: "Failed to delete transaction",
            status: :unprocessable_content,
            details: format_validation_errors(@transaction.errors)
          )
        end
      end

      # POST /api/v1/transactions/parse_voice
      def parse_voice
        text = params[:text].to_s.strip

        if text.blank?
          render_error(
            "VALIDATION_ERROR", message: I18n.t("api.transactions.parse_voice.blank_text"),
            status: :unprocessable_content,
            details: { text: ["can't be blank"] }
          )
          return
        end

        if text.length > 500
          render_error(
            "VALIDATION_ERROR", message: I18n.t("api.transactions.parse_voice.text_too_long"),
            status: :unprocessable_content,
            details: { text: ["is too long (maximum 500 characters)"] }
          )
          return
        end

        result = Transactions::ParseVoiceService.call(text: text, user: current_user)

        if result.success?
          current_user.quota.increment!(:ai_usage_count)
          render json: { data: result.payload, meta: { usage: ::Assistant::UsageMeter.new(current_user).snapshot } },
            status: :ok
        else
          render_error(
            "AI_PARSE_FAILED", message: I18n.t("api.transactions.parse_voice.failed"),
            status: :unprocessable_content
          )
        end
      end

      # POST /api/v1/transactions/parse_image
      def parse_image
        if request.content_length.to_i > 6_700_000
          render_error(
            "IMAGE_TOO_LARGE", message: I18n.t("api.transactions.parse_image.too_large"),
            status: :unprocessable_content
          )
          return
        end

        mime_type = params[:mime_type].to_s.strip
        supported = %w[image/jpeg image/png image/webp]
        unless supported.include?(mime_type)
          render_error(
            "UNSUPPORTED_MIME_TYPE",
            message: I18n.t("api.transactions.parse_image.unsupported_mime"),
            status: :unprocessable_content,
            details: { supported: supported }
          )
          return
        end

        image_base64 = params[:image].to_s.strip
        if image_base64.blank?
          render_error(
            "VALIDATION_ERROR", message: I18n.t("api.transactions.parse_image.blank_image"),
            status: :unprocessable_content,
            details: { image: ["can't be blank"] }
          )
          return
        end

        result = Transactions::ParseImageService.call(
          image_base64: image_base64,
          mime_type: mime_type,
          user: current_user
        )

        if result.success?
          current_user.quota.increment!(:ai_usage_count)
          render json: { data: result.payload, meta: { usage: ::Assistant::UsageMeter.new(current_user).snapshot } },
            status: :ok
        else
          render_error(
            "AI_PARSE_FAILED", message: I18n.t("api.transactions.parse_image.failed"),
            status: :unprocessable_content
          )
        end
      end

      # GET /api/v1/transactions/recurring_suggestions
      def recurring_suggestions
        cutoff = 90.days.ago.to_date

        grouped = current_user.transactions
          .where("date >= ? AND merchant IS NOT NULL AND merchant != ''", cutoff)
          .where(transaction_type: %w[variable_expense fixed_expense])
          .group("LOWER(TRIM(merchant))")
          .having("COUNT(*) >= 2")
          .select(
            "LOWER(TRIM(merchant)) AS merchant_key",
            "MAX(merchant) AS merchant",
            "ROUND(AVG(ABS(amount))::numeric, 2) AS amount",
            "COUNT(*) AS occurrence_count",
            "MAX(date) AS last_seen",
            "MODE() WITHIN GROUP (ORDER BY category_id) AS suggested_category_id"
          )
          .order("occurrence_count DESC, MAX(date) DESC")

        results = grouped.map do |row|
          frequency_days = compute_frequency_days(row.merchant_key, cutoff)
          {
            merchant: row.merchant,
            amount: row.amount.to_f,
            frequency_days: frequency_days,
            last_seen: row.last_seen.to_s,
            suggested_category_id: row.suggested_category_id
          }
        end

        current_user.quota.increment!(:ai_usage_count)
        render json: { data: results, meta: { usage: ::Assistant::UsageMeter.new(current_user).snapshot } }, status: :ok
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

      def check_ai_subscription!
        result = current_user.ai_access_result
        return if result[:allowed]

        code    = result[:reason] == :ai_limit_reached ? "AI_LIMIT_REACHED" : "SUBSCRIPTION_REQUIRED"
        message = result[:message] || I18n.t("api.errors.subscription_required")
        render_error(code, message: message, status: :payment_required)
      end

      def compute_frequency_days(merchant_key, cutoff)
        dates = current_user.transactions
          .where("date >= ? AND LOWER(TRIM(merchant)) = ?", cutoff, merchant_key)
          .where(transaction_type: %w[variable_expense fixed_expense])
          .order(:date)
          .pluck(:date)

        return 30 if dates.length < 2

        gaps = dates.each_cons(2).map { |a, b| (b - a).to_i }
        (gaps.sum.to_f / gaps.length).round
      end

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
          :category_id,
          :transaction_type,
          :source,
          :from_date,
          :to_date,
          :min_amount,
          :max_amount,
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
          :concept,
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
