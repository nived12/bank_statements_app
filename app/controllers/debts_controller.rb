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
        base_scope.where.not(status: "archived").includes(:goals, :category, :bank_account).order(created_at: :desc)
      else
        base_scope.where(status: @selected_status).includes(:goals, :category, :bank_account).order(created_at: :desc)
      end

    # Apply goal filter if present
    @debts = @debts.filtered_by_goal(params[:goal_id]) if params[:goal_id].present?

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
                              .includes(:transaction)
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
    result = Debts::CreateService.call(debt_params)

    respond_to do |format|
      if result.success?
        @debt = result.data
        format.html { redirect_to debt_path(@debt), notice: t("debts.created") }
        format.json { render :show, status: :created, location: @debt }
        format.turbo_stream { redirect_to debt_path(@debt), notice: t("debts.created") }
      else
        @debt = result.data
        load_form_data

        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("debt-form",
            partial: "form",
            locals: { debt: @debt })
        end
      end
    end
  end

  # PATCH/PUT /debts/1
  def update
    respond_to do |format|
      if @debt.update(debt_params)
        format.html { redirect_to debt_path(@debt), notice: t("debts.updated") }
        format.json { render :show, status: :ok, location: @debt }
        format.turbo_stream { redirect_to debt_path(@debt), notice: t("debts.updated") }
      else
        load_form_data

        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @debt.errors, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("debt-form",
            partial: "form",
            locals: { debt: @debt })
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
    @categories = current_user.categories.order(:name)
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name)
  end

  def debt_params
    permitted = params.require(:debt).permit(
      :name,
      :original_amount,
      :current_balance,
      :interest_rate,
      :minimum_payment,
      :category_id,
      :bank_account_id,
      :auto_link_category,
      :icon,
      :color,
      :status,
      :notes,
      # Calculation settings
      :calculation_settings_income,
      :calculation_settings_expense,
      :calculation_settings_transfer_in,
      :calculation_settings_transfer_out
    )

    # Convert individual calculation settings to hash
    if permitted[:calculation_settings_income].present? ||
       permitted[:calculation_settings_expense].present? ||
       permitted[:calculation_settings_transfer_in].present? ||
       permitted[:calculation_settings_transfer_out].present?

      calculation_settings = {}
      calculation_settings["income"] = permitted.delete(:calculation_settings_income) if permitted[:calculation_settings_income].present?
      calculation_settings["expense"] = permitted.delete(:calculation_settings_expense) if permitted[:calculation_settings_expense].present?
      calculation_settings["transfer_in"] = permitted.delete(:calculation_settings_transfer_in) if permitted[:calculation_settings_transfer_in].present?
      calculation_settings["transfer_out"] = permitted.delete(:calculation_settings_transfer_out) if permitted[:calculation_settings_transfer_out].present?

      permitted[:calculation_settings] = calculation_settings
    end

    permitted
  end
end
