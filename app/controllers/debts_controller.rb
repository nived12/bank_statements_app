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
        base_scope.where(status: @selected_status).includes(:goals, :categories, :bank_accounts).order(created_at: :desc)
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
    params_hash = debt_params
    category_ids = params_hash.delete(:category_ids)&.reject(&:blank?) || []
    bank_account_ids = params_hash.delete(:bank_account_ids)&.reject(&:blank?) || []

    respond_to do |format|
      if @debt.update(params_hash)
        # Update category associations
        @debt.category_ids = category_ids
        # Update bank account associations
        @debt.bank_account_ids = bank_account_ids

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
      # Calculation settings
      :calculation_settings_income,
      :calculation_settings_expense,
      :calculation_settings_transfer_in,
      :calculation_settings_transfer_out,
      # Multi-select arrays
      category_ids: [],
      bank_account_ids: []
    )

    # Clean amount fields - remove commas from numbers (backup if JS fails)
    permitted[:original_amount] = permitted[:original_amount].to_s.gsub(/[,\s]/, "") if permitted[:original_amount].present?
    permitted[:current_balance] = permitted[:current_balance].to_s.gsub(/[,\s]/, "") if permitted[:current_balance].present?
    permitted[:interest_rate] = permitted[:interest_rate].to_s.gsub(/[,\s]/, "") if permitted[:interest_rate].present?
    permitted[:minimum_payment] = permitted[:minimum_payment].to_s.gsub(/[,\s]/, "") if permitted[:minimum_payment].present?

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
