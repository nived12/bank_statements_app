# frozen_string_literal: true

class SavingsController < ApplicationController
  before_action :authenticate!
  before_action :set_saving, only: [:show, :edit, :update, :destroy]

  # GET /savings
  def index
    @selected_status = params[:status] || "active"

    # Use Discard gem scopes for archived savings
    base_scope = @selected_status == "archived" ? current_user.savings.discarded : current_user.savings.kept

    @savings =
      if @selected_status == "all"
        base_scope.where.not(status: "archived").includes(:goals, :categories, :bank_accounts).order(created_at: :desc)
      else
        base_scope.where(status: @selected_status).includes(
          :goals, :categories,
          :bank_accounts
        ).order(created_at: :desc)
      end

    # Apply goal filter if present
    @savings = @savings.filter_by_goal(params[:goal_id]) if params[:goal_id].present?

    # Get counts for each status (including both kept and discarded)
    @status_counts = current_user.savings.group(:status).count

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /savings/1
  def show
    @saving_transactions = @saving.saving_transactions
                                 .includes(:transaction_record)
                                 .order(created_at: :desc)

    # Pagination using Pagy
    @pagy_transactions, @saving_transactions = pagy(@saving_transactions, items: 20)

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /savings/new
  def new
    @saving = current_user.savings.build
    load_form_data
  end

  # GET /savings/1/edit
  def edit
    load_form_data
  end

  # POST /savings
  def create
    result = Savings::Creator.call(saving_params)

    if result.success?
      @saving = result.payload
      respond_to do |format|
        format.html { redirect_to saving_path(@saving), notice: t("savings.created") }
        format.json { render :show, status: :created, location: @saving }
        format.turbo_stream do
          redirect_to saving_path(@saving), notice: t("savings.created")
        end
      end
    else
      @saving = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @saving.errors, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /savings/1
  def update
    result = Savings::Updater.call(@saving, saving_params)

    if result.success?
      @saving = result.payload

      respond_to do |format|
        format.html { redirect_to saving_path(@saving), notice: t("savings.updated") }
        format.json { render :show, status: :ok, location: @saving }
        format.turbo_stream do
          redirect_to saving_path(@saving), notice: t("savings.updated")
        end
      end
    else
      @saving = result.payload
      load_form_data

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @saving.errors, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /savings/1
  def destroy
    @saving.destroy!

    respond_to do |format|
      format.html { redirect_to savings_path, status: :see_other, notice: t("savings.deleted") }
      format.json { head :no_content }
      format.turbo_stream { redirect_to savings_path, status: :see_other, notice: t("savings.deleted") }
    end
  end

  private

  def set_saving
    @saving = current_user.savings.find(params[:id])
  end

  def load_form_data
    @goals = current_user.goals.savings_goals.active
    @categories = current_user.categories.hierarchical_order
    @bank_accounts = current_user.bank_accounts.includes(:bank).order(:custom_name)
  end

  def saving_params
    permitted = params.require(:saving).permit(
      :name,
      :target_amount,
      :current_amount,
      :target_date,
      :auto_sync_transactions,
      :icon,
      :color,
      :status,
      :notes,
      # Contribution tracking fields
      :target_contribution_amount,
      :contribution_frequency,
      :contribution_mode,
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
    permitted[:target_amount] = permitted[:target_amount].to_s.gsub(/[,\s]/, "") if permitted[:target_amount].present?
    permitted[:current_amount] =
permitted[:current_amount].to_s.gsub(/[,\s]/, "") if permitted[:current_amount].present?
    permitted[:target_contribution_amount] =
permitted[:target_contribution_amount].to_s.gsub(/[,\s]/, "") if permitted[:target_contribution_amount].present?

    # Convert individual calculation settings to hash
    if permitted[:calculation_settings_income].present? ||
       permitted[:calculation_settings_expense].present? ||
       permitted[:calculation_settings_transfer_in].present? ||
       permitted[:calculation_settings_transfer_out].present?

      calculation_settings = {}
      calculation_settings["income"] =
permitted.delete(:calculation_settings_income) if permitted[:calculation_settings_income].present?
      calculation_settings["expense"] =
permitted.delete(:calculation_settings_expense) if permitted[:calculation_settings_expense].present?
      calculation_settings["transfer_in"] =
permitted.delete(:calculation_settings_transfer_in) if permitted[:calculation_settings_transfer_in].present?
      calculation_settings["transfer_out"] =
permitted.delete(:calculation_settings_transfer_out) if permitted[:calculation_settings_transfer_out].present?

      permitted[:calculation_settings] = calculation_settings
    end

    # Add user to params
    permitted[:user_id] = current_user.id

    permitted
  end
end
