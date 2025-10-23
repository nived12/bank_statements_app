# frozen_string_literal: true

##
# Goals::CreateService
# Service for creating new goals (savings goals or debt payoff goals)
# Validates parameters and creates the goal with proper defaults
#
class Goals::CreateService < ApplicationService
  def initialize(user, goal_params)
    super()
    @user = user
    @goal_params = goal_params
  end

  def call
    validate_params
    return failure if has_errors?

    create_goal
    return failure if has_errors?

    success(goal)
  end

  private

  attr_reader :user, :goal_params, :goal

  def validate_params
    required_fields = %i[name goal_type start_date deadline]
    missing_fields = required_fields - goal_params.keys.map(&:to_sym)

    if missing_fields.any?
      errors.add(:base, "Missing required fields: #{missing_fields.join(", ")}")
    end

    # Validate debt payoff specific fields
    if goal_params[:goal_type] == "debt_payoff"
      if goal_params[:debt_strategy].blank?
        errors.add(:debt_strategy, "must be selected for debt payoff goals")
      end
    end

    # Validate dates
    if goal_params[:start_date].present? && goal_params[:deadline].present?
      start_date = parse_date(goal_params[:start_date])
      deadline = parse_date(goal_params[:deadline])

      if start_date && deadline && deadline <= start_date
        errors.add(:deadline, "must be after start date")
      end
    end
  end

  def create_goal
    @goal = user.goals.build(goal_params)

    unless goal.save
      goal.errors.each do |error|
        errors.add(error.attribute, error.message)
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
      user_id: user&.id,
      goal_type: goal_params[:goal_type],
      goal_name: goal_params[:name]
    }
  end
end
