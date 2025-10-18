# frozen_string_literal: true

##
# Goals::CompleteGoalService
# Service for marking a goal as completed
# Validates that goal has reached its target before marking complete
#
class Goals::CompleteGoalService < ApplicationService
  def initialize(goal, force: false)
    super()
    @goal = goal
    @force = force
  end

  def call
    validate_params
    return failure if has_errors?

    complete_goal
    return failure if has_errors?

    success(goal)
  end

  private

  attr_reader :goal, :force

  def validate_params
    if goal.blank?
      errors.add(:goal, "must be present")
      return
    end

    if goal.status_completed?
      errors.add(:goal, "is already completed")
      return
    end

    # Check if goal has reached target (unless forced)
    unless force
      if goal.type_savings_goal? && goal.current_amount < goal.target_amount
        errors.add(:goal, "has not reached target amount yet (#{goal.current_amount} / #{goal.target_amount})")
      elsif goal.type_debt_payoff?
        remaining_debt = goal.starting_debt_amount - goal.current_amount
        if remaining_debt > goal.target_amount
          errors.add(:goal, "debt has not been paid down to target yet (#{remaining_debt} remaining)")
        end
      end
    end
  end

  def complete_goal
    unless goal.complete_goal!
      errors.add(:base, "Failed to mark goal as completed")
    end
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name,
      forced: force,
      progress_percentage: goal&.progress_percentage
    }
  end
end
