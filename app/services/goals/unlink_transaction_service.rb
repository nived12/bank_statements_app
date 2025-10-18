# frozen_string_literal: true

##
# Goals::UnlinkTransactionService
# Service for unlinking a transaction from a goal
# Updates goal progress and may revert completion status
#
class Goals::UnlinkTransactionService < ApplicationService
  def initialize(goal, transaction)
    super()
    @goal = goal
    @transaction = transaction
  end

  def call
    validate_params
    return failure if has_errors?

    find_goal_transaction
    return failure if has_errors?

    unlink_transaction
    return failure if has_errors?

    # Check if goal should be reverted from completed
    check_goal_reversion

    success(goal)
  end

  private

  attr_reader :goal, :transaction, :goal_transaction

  def validate_params
    if goal.blank?
      errors.add(:goal, "must be present")
      return
    end

    if transaction.blank?
      errors.add(:transaction, "must be present")
    end
  end

  def find_goal_transaction
    @goal_transaction = GoalTransaction.find_by(goal: goal, transaction_id: transaction.id)

    if goal_transaction.blank?
      errors.add(:base, "Transaction is not linked to this goal")
    end
  end

  def unlink_transaction
    unless goal_transaction.destroy
      errors.add(:base, "Failed to unlink transaction")
    end
  end

  def check_goal_reversion
    return unless goal.status_completed?

    goal.reload

    # If goal is no longer meeting target, revert to active
    if goal.type_savings_goal? && goal.current_amount < goal.target_amount
      goal.update!(status: "active")
    elsif goal.type_debt_payoff?
      remaining_debt = goal.starting_debt_amount - goal.current_amount
      if remaining_debt > goal.target_amount
        goal.update!(status: "active")
      end
    end
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name,
      transaction_id: transaction&.id
    }
  end
end
