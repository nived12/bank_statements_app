# frozen_string_literal: true

class DebtsController < ApplicationController
  before_action :authenticate!
  before_action :require_confirmed_user!, only: %i[create update destroy]
  before_action :set_debt, only: [:show, :edit, :update, :destroy]

  # GET /debts
  def index
    @selected_status = params[:status] || "active"

    # Use Discard gem scopes for archived debts
    base_scope = @selected_status == "archived" ? current_user.debts.discarded : current_user.debts.kept

    @debts =
      if @selected_status == "all"
        base_scope.where.not(status: "archived").includes(:goals, :categories, :bank_accounts).order(created_at: :desc)
      else
        base_scope.where(status: @selected_status).includes(
          :goals, :categories,
          :bank_accounts
        ).order(created_at: :desc)
      end

    # Apply goal filter if present
    @debts = @debts.filter_by_goal(params[:goal_id]) if params[:goal_id].present?

    # Apply ordering based on goal strategy
    @debts = @debts.ordered_by_priority(params[:goal_id]) if params[:goal_id].present?

    # Get counts for each status (including both kept and discarded)
    @status_counts = current_user.debts.group(:status).count

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /debts/1
  def show
    @debt_transactions = @debt.debt_transactions
                              .includes(:transaction_record)
                              .order(created_at: :desc)

    # Pagination using Pagy
    @pagy_transactions, @debt_transactions = pagy(@debt_transactions, items: 20)

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /debts/new
  def new
    @debt = current_user.debts.build(template_attributes)
    load_form_data
  end

  # GET /debts/1/edit
  def edit
    load_form_data
  end

  # POST /debts
  def create
    result = Debts::Creator.call(debt_params)

    if result.success?
      @debt = result.payload
      notice = [t("debts.created"), backfill_notice(@debt)].compact.join(" ")
      respond_to do |format|
        format.html { redirect_to debt_path(@debt), notice: notice }
        format.json { render :show, status: :created, location: @debt }
        format.turbo_stream do
          redirect_to debt_path(@debt), notice: notice
        end
      end
    else
      @debt = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @debt.errors, status: :unprocessable_content }
        format.turbo_stream { render :new, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /debts/1
  def update
    result = Debts::Updater.call(@debt, debt_params)

    if result.success?
      @debt = result.payload
      notice = [t("debts.updated"), backfill_notice(@debt)].compact.join(" ")

      respond_to do |format|
        format.html { redirect_to debt_path(@debt), notice: notice }
        format.json { render :show, status: :ok, location: @debt }
        format.turbo_stream do
          redirect_to debt_path(@debt), notice: notice
        end
      end
    else
      @debt = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @debt.errors, status: :unprocessable_content }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("debt_form", partial: "form", locals: { debt: @debt })
        end
      end
    end
  end

  # DELETE /debts/1
  def destroy
    @debt.destroy!

    respond_to do |format|
      format.html { redirect_to debts_path, status: :see_other, notice: t("debts.deleted") }
      format.json { head :no_content }
      format.turbo_stream { redirect_to debts_path, status: :see_other, notice: t("debts.deleted") }
    end
  end

  private

  def set_debt
    @debt = current_user.debts.find(params[:id])
  end

  # Surfaces Debts::Creator/Updater's backfill/re-anchor result, if any, as extra
  # notice text so the user knows their linked transactions changed underneath them.
  def backfill_notice(debt)
    summary = debt.backfill_summary
    return if summary.blank?

    parts = []
    parts << t("debts.backfilled_toast", count: summary[:linked]) if summary[:linked].to_i.positive?
    parts << t("debts.unlinked_toast", count: summary[:unlinked]) if summary[:unlinked].to_i.positive?
    parts.join(" ")
  end

  def load_form_data
    @goals = current_user.goals.debt_payoff_goals.active
    @categories = current_user.categories.hierarchical_order
    @bank_accounts = current_user.bank_accounts.kept.includes(:bank).order(:custom_name)
  end

  # Pre-fill attributes from a starter template (params[:template]); blank otherwise.
  def template_attributes
    template = FinancialTemplate.find("debt", params[:template])
    return {} unless template

    {
      name: FinancialTemplate.name_for("debt", template[:key]),
      icon: template[:icon],
      color: template[:color],
      interest_rate: template[:suggested_interest_rate],
      calculation_settings: template[:calculation_settings].stringify_keys,
      category_ids: template_category_ids(template)
    }
  end

  # Resolve the template's suggested category (by name) to the user's own
  # category record so the form pre-checks it. Empty if the user lacks it.
  def template_category_ids(template)
    return [] if template[:category_name].blank?

    current_user.categories.where(name: template[:category_name]).pluck(:id)
  end

  def debt_params
    permitted = params.require(:debt).permit(
      :name,
      :original_amount,
      :opening_balance,
      :opening_balance_date,
      :interest_rate,
      :minimum_payment,
      :auto_sync_transactions,
      :icon,
      :color,
      :status,
      :notes,
      :due_day_of_month,
      :payment_frequency,
      :payment_mode,
      :target_payment_amount,
      :target_payoff_date,
      :calculation_settings_income,
      :calculation_settings_expense,
      :calculation_settings_transfer_in,
      :calculation_settings_transfer_out,
      category_ids: [],
      bank_account_ids: []
    )

    transform_calculation_settings!(permitted)
    permitted.merge(user_id: current_user.id)
  end

  def transform_calculation_settings!(params)
    settings = {}
    %w[income expense transfer_in transfer_out].each do |type|
      key = "calculation_settings_#{type}"
      settings[type] = params.delete(key.to_sym) if params[key.to_sym].present?
    end
    params[:calculation_settings] = settings if settings.any?
  end
end
