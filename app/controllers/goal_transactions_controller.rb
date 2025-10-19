# frozen_string_literal: true

class GoalTransactionsController < ApplicationController
  before_action :authenticate!
  before_action :set_goal, only: [:create, :destroy]
  before_action :set_transaction, only: [:create]
  before_action :set_goal_transaction, only: [:destroy]

  # POST /goals/:goal_id/transactions
  # POST /goal_transactions
  def create
    # Support both nested and flat routes
    goal = @goal || current_user.goals.find(goal_transaction_params[:goal_id])
    transaction = @transaction || current_user.transactions.find(goal_transaction_params[:transaction_id])
    amount_applied = goal_transaction_params[:amount_applied]
    notes = goal_transaction_params[:notes]

    result = Goals::LinkTransactionService.call(goal, transaction, amount_applied, notes: notes)

    respond_to do |format|
      if result.success?
        @goal_transaction = result.payload

        format.html do
          redirect_back fallback_location: goal_path(goal),
                        notice: I18n.t("goals.linked_transactions.title")
        end
        format.json { render json: @goal_transaction, status: :created }
        format.turbo_stream do
          # Render turbo stream to update the goal progress and linked transactions list
          render turbo_stream: [
            turbo_stream.replace("goal-#{goal.id}-progress",
              partial: "goals/progress",
              locals: { goal: goal }),
            turbo_stream.prepend("goal-#{goal.id}-transactions",
              partial: "goals/goal_transaction",
              locals: { goal_transaction: @goal_transaction, goal: goal })
          ]
        end
      else
        format.html do
          redirect_back fallback_location: goal_path(goal),
                        alert: result.errors.full_messages.join(", ")
        end
        format.json { render json: { errors: result.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("goal-transaction-form",
            partial: "goal_transactions/form_errors",
            locals: { errors: result.errors })
        end
      end
    end
  end

  # DELETE /goals/:goal_id/transactions/:id
  # DELETE /goal_transactions/:id
  def destroy
    goal = @goal_transaction.goal
    transaction = @goal_transaction.txn

    result = Goals::UnlinkTransactionService.call(goal, transaction)

    respond_to do |format|
      if result.success?
        format.html do
          redirect_back fallback_location: goal_path(goal),
                        notice: I18n.t("goals.actions.unlink_transaction")
        end
        format.json { head :no_content }
        format.turbo_stream do
          # Remove the goal transaction row and update progress
          render turbo_stream: [
            turbo_stream.remove("goal-transaction-#{@goal_transaction.id}"),
            turbo_stream.replace("goal-#{goal.id}-progress",
              partial: "goals/progress",
              locals: { goal: goal })
          ]
        end
      else
        format.html do
          redirect_back fallback_location: goal_path(goal),
                        alert: result.errors.full_messages.join(", ")
        end
        format.json { render json: { errors: result.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_goal
    if params[:goal_id].present?
      @goal = current_user.goals.find(params[:goal_id])
    end
  end

  def set_transaction
    if params[:transaction_id].present?
      @transaction = current_user.transactions.find(params[:transaction_id])
    end
  end

  def set_goal_transaction
    # Support both nested and flat routes
    if params[:goal_id].present?
      goal = current_user.goals.find(params[:goal_id])
      @goal_transaction = goal.goal_transactions.find(params[:id])
    else
      # Flat route - find via current user's goals
      @goal_transaction = GoalTransaction.joins(:goal)
                                        .where(goals: { user_id: current_user.id })
                                        .find(params[:id])
    end
  end

  def goal_transaction_params
    params.require(:goal_transaction).permit(:goal_id, :transaction_id, :amount_applied, :notes)
  end
end
