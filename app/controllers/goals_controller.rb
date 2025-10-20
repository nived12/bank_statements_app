# frozen_string_literal: true

class GoalsController < ApplicationController
  before_action :authenticate!
  before_action :set_goal, only: [:show, :edit, :update, :destroy]

  # GET /goals
  def index
    @selected_status = params[:status] || "active"

    # Use Discard gem scopes for archived goals
    base_scope = @selected_status == "archived" ? current_user.goals.discarded : current_user.goals.kept

    @goals =
      if @selected_status == "all"
        base_scope.where.not(status: "archived").order(created_at: :desc)
      else
        base_scope.where(status: @selected_status).order(created_at: :desc)
      end

    # Get counts for each status (including both kept and discarded)
    @status_counts = current_user.goals.group(:status).count

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /goals/:id
  def show
    # Calculate progress metrics
    progress_result = Goals::CalculateProgressService.call(@goal)
    @progress = progress_result.payload if progress_result.success?

    # Get linked transactions
    @goal_transactions = @goal.goal_transactions
                              .includes(txn: [:bank_account, :category])
                              .order("transactions.date DESC, transactions.created_at DESC")

    respond_to do |format|
      format.html
      format.json
    end
  end

  # GET /goals/new
  def new
    @goal = current_user.goals.new
    @categories = current_user.categories.order(:name)
    @bank_accounts = current_user.bank_accounts.order(:custom_name)
  end

  # POST /goals
  def create
    result = Goals::CreateService.call(current_user, goal_params.to_h)

    respond_to do |format|
      if result.success?
        @goal = result.payload
        format.html { redirect_to goal_path(@goal), notice: t("goals.created") }
        format.json { render :show, status: :created, location: @goal }
        format.turbo_stream { redirect_to goal_path(@goal), notice: t("goals.created") }
      else
        @goal = Goal.new(goal_params)
        @goal.errors.merge!(result.errors)
        @categories = current_user.categories.order(:name)
        @bank_accounts = current_user.bank_accounts.order(:custom_name)

        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @goal.errors, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("goal-form",
            partial: "form",
            locals: { goal: @goal, categories: @categories })
        end
      end
    end
  end

  # GET /goals/:id/edit
  def edit
    # @goal is set by before_action
    @categories = current_user.categories.order(:name)
    @bank_accounts = current_user.bank_accounts.order(:custom_name)
  end

  # PATCH /goals/:id
  def update
    # Prepare parameters for the service
    service_params = {}

    # Handle status actions
    if params[:status_action].present?
      service_params[:status_action] = params[:status_action]
      service_params[:force] = params[:force] if params[:force].present?
    else
      # Regular goal updates
      service_params = goal_params.to_h
    end

    result = Goals::UpdateService.call(@goal, service_params)

    respond_to do |format|
      if result.success?
        # Determine appropriate redirect and notice based on action
        redirect_path, notice_key = determine_redirect_and_notice(params[:status_action])

        format.html { redirect_to redirect_path, notice: t(notice_key) }
        format.json { render :show, status: :ok, location: @goal }
        format.turbo_stream { redirect_to redirect_path, notice: t(notice_key) }
      else
        @goal.errors.merge!(result.errors)
        @categories = current_user.categories.order(:name)
        @bank_accounts = current_user.bank_accounts.order(:custom_name)

        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @goal.errors, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("goal-form",
            partial: "form",
            locals: { goal: @goal, categories: @categories })
        end
      end
    end
  end

  # DELETE /goals/:id
  def destroy
    # Unlink all transactions (goal_transactions will be destroyed via dependent: :destroy)
    @goal.destroy

    respond_to do |format|
      format.html { redirect_to goals_path, status: :see_other, notice: t("goals.deleted") }
      format.json { head :no_content }
      format.turbo_stream { redirect_to goals_path, status: :see_other, notice: t("goals.deleted") }
    end
  end


  private

  def set_goal
    # Include discarded goals so archived goals can be viewed and unarchived
    @goal = current_user.goals.with_discarded.find(params[:id])
  end

  def determine_redirect_and_notice(status_action)
    redirect_path = status_action == "archive" ? goals_path : goal_path(@goal)
    notice_key = "goals.#{status_action.present? ? status_action : "updated"}"
    [redirect_path, notice_key]
  end

  def goal_params
    permitted = params.require(:goal).permit(
      :name,
      :goal_type,
      :target_amount,
      :start_date,
      :deadline,
      :category_id,
      :auto_link_category,
      :bank_account_id,
      :debt_strategy,
      :starting_debt_amount,
      :icon,
      :color,
      :notes,
      :goal_calculation_settings_income,
      :goal_calculation_settings_expense,
      :goal_calculation_settings_transfer_in,
      :goal_calculation_settings_transfer_out
    )

    # Convert individual calculation settings to hash format
    calculation_settings = {}
    %w[income expense transfer_in transfer_out].each do |tx_type|
      setting_key = "goal_calculation_settings_#{tx_type}".to_sym
      if permitted[setting_key].present?
        calculation_settings[tx_type] = permitted[setting_key]
        permitted.delete(setting_key) # Remove the individual parameter
      end
    end

    # Add the hash back to permitted params
    permitted[:goal_calculation_settings] = calculation_settings if calculation_settings.any?

    # Sanitize money fields by removing commas
    permitted[:target_amount] = sanitize_money_field(permitted[:target_amount]) if permitted[:target_amount].present?
    permitted[:starting_debt_amount] = sanitize_money_field(permitted[:starting_debt_amount]) if permitted[:starting_debt_amount].present?

    permitted
  end

  def sanitize_money_field(value)
    value.to_s.delete(",")
  end
end
