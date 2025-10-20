# frozen_string_literal: true

##
# Goals::ProjectCompletionService
# Service for calculating projected completion date based on hypothetical monthly contributions
# Used for "What If" calculator functionality
#
class Goals::ProjectCompletionService < ApplicationService
  def initialize(goal, hypothetical_monthly_amount)
    super()
    @goal = goal
    @hypothetical_monthly_amount = hypothetical_monthly_amount.to_f
  end

  def call
    validate_params
    return failure if has_errors?

    calculate_projection

    success(projection)
  end

  private

  attr_reader :goal, :hypothetical_monthly_amount, :projection

  def validate_params
    if goal.blank?
      errors.add(:goal, "must be present")
      return
    end

    if hypothetical_monthly_amount <= 0
      errors.add(:hypothetical_monthly_amount, "must be greater than 0")
    end

    if goal.status_completed?
      errors.add(:goal, "is already completed")
    end
  end

  def calculate_projection
    remaining = goal.amount_remaining.to_f
    current_amount = goal.current_amount.to_f

    if remaining <= 0
      # Goal is already met
      @projection = {
        projected_completion_date: Date.today,
        months_to_completion: 0,
        will_meet_deadline: true,
        days_before_deadline: goal.days_remaining,
        total_contributions_needed: 0,
        amount_remaining: 0
      }
      return
    end

    # Calculate months needed
    months_needed = (remaining / hypothetical_monthly_amount).ceil

    # Calculate projected completion date
    projected_date = Date.today + months_needed.months

    # Check if will meet deadline
    will_meet = projected_date <= goal.deadline

    # Calculate how many days before/after deadline
    days_difference = (goal.deadline - projected_date).to_i

    @projection = {
      projected_completion_date: projected_date,
      months_to_completion: months_needed,
      will_meet_deadline: will_meet,
      days_before_deadline: days_difference,
      days_after_deadline: will_meet ? 0 : days_difference.abs,
      total_contributions_needed: months_needed * hypothetical_monthly_amount,
      amount_remaining: remaining,
      hypothetical_monthly_amount: hypothetical_monthly_amount,

      # Comparison with current pace
      current_monthly_pace: goal.actual_monthly_contribution.to_f,
      pace_difference: hypothetical_monthly_amount - goal.actual_monthly_contribution.to_f,
      pace_improvement_percentage: calculate_pace_improvement,

      # Current projection for comparison
      current_projected_date: goal.projected_completion_date,
      time_saved_months: calculate_time_saved(months_needed)
    }
  end

  def calculate_pace_improvement
    current_pace = goal.actual_monthly_contribution.to_f
    return 0 if current_pace.zero?

    ((hypothetical_monthly_amount - current_pace) / current_pace * 100).round(2)
  end

  def calculate_time_saved(new_months_needed)
    current_remaining = goal.amount_remaining.to_f
    current_pace = goal.actual_monthly_contribution.to_f

    return 0 if current_pace.zero?

    current_months_needed = (current_remaining / current_pace).ceil
    time_saved = current_months_needed - new_months_needed

    [time_saved, 0].max
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name,
      hypothetical_amount: hypothetical_monthly_amount
    }
  end
end
