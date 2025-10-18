# frozen_string_literal: true

##
# Goals::UpdateService
# Service for updating existing goals
# Handles validation and status changes
#
class Goals::UpdateService < ApplicationService
  def initialize(goal, goal_params)
    super()
    @goal = goal
    @goal_params = goal_params
  end

  def call
    validate_params
    return failure if has_errors?

    update_goal
    return failure if has_errors?

    # Check if goal should be auto-completed
    check_auto_completion if goal.status_active?

    success(goal)
  end

  private

  attr_reader :goal, :goal_params

  def validate_params
    # Validate dates if being updated
    if goal_params[:start_date].present? && goal_params[:deadline].present?
      start_date = parse_date(goal_params[:start_date])
      deadline = parse_date(goal_params[:deadline])

      if start_date && deadline && deadline <= start_date
        errors.add(:deadline, "must be after start date")
      end
    elsif goal_params[:deadline].present?
      deadline = parse_date(goal_params[:deadline])
      if deadline && deadline <= goal.start_date
        errors.add(:deadline, "must be after start date")
      end
    elsif goal_params[:start_date].present?
      start_date = parse_date(goal_params[:start_date])
      if start_date && goal.deadline <= start_date
        errors.add(:start_date, "must be before deadline")
      end
    end

    # Validate debt payoff specific fields
    if goal_params[:goal_type] == "debt_payoff" || goal.type_debt_payoff?
      if goal_params[:debt_strategy].blank? && goal.debt_strategy.blank?
        errors.add(:debt_strategy, "must be selected for debt payoff goals")
      end
    end
  end

  def update_goal
    unless goal.update(goal_params)
      goal.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end

  def check_auto_completion
    if goal.type_savings_goal? && goal.current_amount >= goal.target_amount
      goal.complete_goal!
    elsif goal.type_debt_payoff?
      remaining_debt = goal.starting_debt_amount - goal.current_amount
      if remaining_debt <= goal.target_amount
        goal.complete_goal!
      end
    end
  end

  def parse_date(date_value)
    return date_value if date_value.is_a?(Date)
    Date.parse(date_value.to_s)
  rescue ArgumentError
    nil
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name,
      updated_fields: goal_params.keys
    }
  end
end
