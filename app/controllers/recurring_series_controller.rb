# frozen_string_literal: true

class RecurringSeriesController < ApplicationController
  before_action :require_confirmed_user!
  before_action :require_recurring_access!
  before_action :set_series, only: %i[show edit update destroy process_due]

  # GET /recurring
  def index
    scope = current_user.recurring_series
    scope = scope.where(status: params[:status]) if params[:status].present?
    @series = scope.order(:next_due_date)
    @summary = build_summary
  end

  # GET /recurring/:id
  def show
    @transactions = @series.transactions.order(date: :desc).limit(50)
  end

  # GET /recurring/new
  def new
    @series = current_user.recurring_series.new(
      frequency: "monthly",
      transaction_type: "fixed_expense",
      next_due_date: Date.current + 7
    )
  end

  # GET /recurring/:id/edit
  def edit; end

  # POST /recurring
  def create
    @series = current_user.recurring_series.new(series_params.merge(source: "manual", status: "active"))
    @series.description_signature ||= "manual-#{SecureRandom.hex(6)}"

    if @series.save
      redirect_to recurring_series_path(@series), notice: t("recurring.flash.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH /recurring/:id
  def update
    if @series.update(series_params)
      redirect_to recurring_series_path(@series), notice: t("recurring.flash.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /recurring/:id
  def destroy
    @series.destroy!
    redirect_to recurring_series_index_path, notice: t("recurring.flash.deleted")
  end

  # POST /recurring/:id/process_due
  def process_due
    processor = ::Recurring::DueProcessor.new(@series)
    case params[:action_type].to_s
    when "confirm"
      processor.confirm(amount: params[:amount].presence, date: params[:date].presence)
      redirect_to recurring_series_index_path, notice: t("recurring.flash.confirmed")
    when "skip"
      processor.skip
      redirect_to recurring_series_index_path, notice: t("recurring.flash.skipped")
    else
      redirect_to recurring_series_index_path, alert: t("recurring.flash.invalid_action")
    end
  rescue ::Recurring::DueProcessor::NoBankAccountError
    redirect_to recurring_series_index_path, alert: t("recurring.errors.no_bank_account")
  end

  # POST /recurring/scan
  def scan
    ::Recurring::Detector.new(current_user).call
    redirect_to recurring_series_index_path, notice: t("recurring.flash.scanned")
  end

  private

  def require_recurring_access!
    result = current_user.ai_access_result
    return if result[:allowed]

    redirect_to pricing_path, alert: result[:message] || t("api.errors.subscription_required")
  end

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

  def build_summary
    active = current_user.recurring_series.active
    totals = RecurringSeries.totals_for(active)
    {
      monthly_total:  totals[:monthly_total],
      annual_total:   totals[:annual_total],
      active_count:   totals[:count],
      detected_count: current_user.recurring_series.detected.count,
      upcoming:       active.upcoming_within(7).order(:next_due_date)
    }
  end
end
