# frozen_string_literal: true

class GoalTransactionsController < ApplicationController
  before_action :authenticate!
  before_action :set_goal_transaction, only: [:destroy]

  # DELETE /goals/:goal_id/transactions/:id
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

  def set_goal_transaction
    goal = current_user.goals.find(params[:goal_id])
    @goal_transaction = goal.goal_transactions.find(params[:id])
  end
end
