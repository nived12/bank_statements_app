# frozen_string_literal: true

module Api
  module V1
    class RecurringController < BaseController
      # `except` not `only`, so a write action added later is guarded by default.
      before_action :require_confirmed_user!, except: %i[index show]
      before_action :check_ai_subscription!
      before_action :set_series, only: %i[show update destroy process_due]

      # GET /api/v1/recurring
      def index
        scope = current_user.recurring_series
        scope = scope.where(status: params[:status]) if params[:status].present?
        @series = scope.order(:next_due_date)
        @summary = build_summary(current_user)
      end

      # POST /api/v1/recurring
      def create
        @series = current_user.recurring_series.new(series_params.merge(source: "manual", status: "active"))
        @series.description_signature ||= "manual-#{SecureRandom.hex(6)}"

        if @series.save
          render :show, status: :created
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create recurring series",
            status: :unprocessable_content,
            details: @series.errors.full_messages
          )
        end
      end

      # GET /api/v1/recurring/:id
      def show
        @transactions = @series.transactions.order(date: :desc).limit(50)
      end

      # PATCH /api/v1/recurring/:id
      def update
        if @series.update(series_params)
          render :show
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update recurring series",
            status: :unprocessable_content,
            details: @series.errors.full_messages
          )
        end
      end

      # DELETE /api/v1/recurring/:id
      def destroy
        @series.destroy!
        head :no_content
      end

      # POST /api/v1/recurring/:id/process_due
      def process_due
        action = params[:action_type].to_s
        processor = ::Recurring::DueProcessor.new(@series)

        case action
        when "confirm"
          @transaction = processor.confirm(amount: params[:amount], date: params[:date])
          render json: { data: { id: @series.id, transaction_id: @transaction.id,
                                 next_due_date: @series.reload.next_due_date } }, status: :ok
        when "skip"
          processor.skip
          render json: { data: { id: @series.id, next_due_date: @series.reload.next_due_date } }, status: :ok
        else
          render_error(
            "INVALID_ACTION",
            message: "action_type must be 'confirm' or 'skip'",
            status: :unprocessable_content
          )
        end
      rescue ::Recurring::DueProcessor::NoBankAccountError
        render_error(
          "NO_BANK_ACCOUNT",
          message: I18n.t("recurring.errors.no_bank_account"),
          status: :unprocessable_content
        )
      end

      # POST /api/v1/recurring/scan
      def scan
        ::Recurring::Detector.new(current_user).call
        @series = current_user.recurring_series.detected.order(detected_at: :desc)
        render :scan
      end

      private

      def set_series
        @series = current_user.recurring_series.find(params[:id])
      end

      def series_params
        params.require(:recurring_series).permit(
          :name, :expected_amount, :frequency, :custom_interval_days,
          :next_due_date, :transaction_type, :category_id, :merchant_hint,
          :notes, :status, :amount_variance_pct
        )
      end

      def check_ai_subscription!
        result = current_user.ai_access_result
        return if result[:allowed]

        code    = result[:reason] == :ai_limit_reached ? "AI_LIMIT_REACHED" : "SUBSCRIPTION_REQUIRED"
        message = result[:message] || I18n.t("api.errors.subscription_required")
        render_error(code, message: message, status: :payment_required)
      end

      def build_summary(user)
        active = user.recurring_series.active
        totals = RecurringSeries.totals_for(active)
        {
          monthly_total:  totals[:monthly_total],
          annual_total:   totals[:annual_total],
          active_count:   totals[:count],
          detected_count: user.recurring_series.detected.count,
          upcoming:       active.upcoming_within(7).order(:next_due_date)
        }
      end
    end
  end
end
