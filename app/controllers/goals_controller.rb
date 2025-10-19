# frozen_string_literal: true

class GoalsController < ApplicationController
  before_action :authenticate!
  before_action :set_goal, only: [:show, :edit, :update, :destroy, :complete, :pause, :resume, :archive]

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
    # @goal is set by before_action

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
        format.html { redirect_to goals_path, notice: t("goals.created") }
        format.json { render :show, status: :created, location: @goal }
        format.turbo_stream
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
    result = Goals::UpdateService.call(@goal, goal_params.to_h)

    respond_to do |format|
      if result.success?
        format.html { redirect_to goal_path(@goal), notice: t("goals.updated") }
        format.json { render :show, status: :ok, location: @goal }
        format.turbo_stream
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
      format.turbo_stream
    end
  end

  # PATCH /goals/:id/complete
  def complete
    force = params[:force].present? && params[:force] == "true"
    result = Goals::CompleteGoalService.call(@goal, force: force)

    respond_to do |format|
      if result.success?
        format.html { redirect_to goal_path(@goal), notice: t("goals.completed") }
        format.json { render :show, status: :ok, location: @goal }
        format.turbo_stream
      else
        format.html { redirect_to goal_path(@goal), alert: result.errors.full_messages.join(", ") }
        format.json { render json: { errors: result.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /goals/:id/pause
  def pause
    if @goal.pause!
      respond_to do |format|
        format.html { redirect_to goal_path(@goal), notice: t("goals.paused") }
        format.json { render :show, status: :ok, location: @goal }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to goal_path(@goal), alert: @goal.errors.full_messages.join(", ") }
        format.json { render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /goals/:id/resume
  def resume
    if @goal.resume!
      respond_to do |format|
        format.html { redirect_to goal_path(@goal), notice: t("goals.resumed") }
        format.json { render :show, status: :ok, location: @goal }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to goal_path(@goal), alert: @goal.errors.full_messages.join(", ") }
        format.json { render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /goals/:id/archive
  def archive
    if @goal.archive!
      respond_to do |format|
        format.html { redirect_to goals_path, notice: t("goals.archived") }
        format.json { head :no_content }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to goal_path(@goal), alert: @goal.errors.full_messages.join(", ") }
        format.json { render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_goal
    @goal = current_user.goals.find(params[:id])
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
