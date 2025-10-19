# frozen_string_literal: true

class GoalsController < ApplicationController
  before_action :authenticate!
  before_action :set_goal, only: [:show, :edit, :update, :destroy]

  # GET /goals
  def index
    @goals = current_user.goals.order(created_at: :desc)
    @active_goals = @goals.where(status: "active")
    @completed_goals = @goals.where(status: "completed")

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
    @goal = current_user.goals.find(params[:id])
  end

  def determine_redirect_and_notice(status_action)
    redirect_path = status_action == "archive" ? goals_path : goal_path(@goal)
    notice_key = "goals.#{status_action.present? ? status_action : "updated"}"
    [redirect_path, notice_key]
  end

  def goal_params
    params.require(:goal).permit(
      :name,
      :goal_type,
      :target_amount,
      :start_date,
      :deadline,
      :category_id,
      :auto_link_category,
      :debt_strategy,
      :starting_debt_amount,
      :icon,
      :color,
      :notes
    )
  end
end
