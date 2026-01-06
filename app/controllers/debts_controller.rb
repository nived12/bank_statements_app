# frozen_string_literal: true

class DebtsController < ApplicationController
  before_action :authenticate!
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
    @debt = current_user.debts.build
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
      respond_to do |format|
        format.html { redirect_to debt_path(@debt), notice: t("debts.created") }
        format.json { render :show, status: :created, location: @debt }
        format.turbo_stream do
          redirect_to debt_path(@debt), notice: t("debts.created")
        end
      end
    else
      @debt = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /debts/1
  def update
    result = Debts::Updater.call(@debt, debt_params)

    if result.success?
      @debt = result.payload

      respond_to do |format|
        format.html { redirect_to debt_path(@debt), notice: t("debts.updated") }
        format.json { render :show, status: :ok, location: @debt }
        format.turbo_stream do
          redirect_to debt_path(@debt), notice: t("debts.updated")
        end
      end
    else
      @debt = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
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

  def load_form_data
    @goals = current_user.goals.debt_payoff_goals.active
    @categories = current_user.categories.hierarchical_order
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name)
  end

  def debt_params
    permitted = params.require(:debt).permit(
      :name,
      :original_amount,
      :current_balance,
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
