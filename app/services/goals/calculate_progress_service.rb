# frozen_string_literal: true

##
# Goals::CalculateProgressService
# Service for calculating comprehensive progress metrics for a goal
# Returns all relevant metrics in a structured format
#
class Goals::CalculateProgressService < ApplicationService
  def initialize(goal)
    super()
    @goal = goal
  end

  def call
    return failure if goal.blank?

    calculate_metrics

    success(metrics)
  end

  private

  attr_reader :goal, :metrics

  def calculate_metrics
    @metrics = {
      # Progress metrics
      progress_percentage: goal.progress_percentage,
      current_amount: goal.current_amount.to_f,
      target_amount: goal.target_amount.to_f,
      amount_remaining: goal.amount_remaining.to_f,

      # Time metrics
      days_remaining: goal.days_remaining,
      months_remaining: goal.months_remaining,
      days_since_start: (Date.today - goal.start_date).to_i,
      months_since_start: goal.months_since_start,

      # Contribution metrics
      monthly_contribution_needed: goal.monthly_contribution_needed.to_f,
      actual_monthly_contribution: goal.actual_monthly_contribution.to_f,

      # Status indicators
      on_track: goal.on_track?,
      behind_schedule: goal.behind_schedule?,
      past_deadline: goal.past_deadline?,
      approaching_deadline: goal.approaching_deadline?,

      # Time progress
      time_elapsed_percentage: goal.time_elapsed_percentage,

      # Projected completion
      projected_completion_date: goal.projected_completion_date,

      # Goal details
      status: goal.status,
      goal_type: goal.goal_type,
      deadline: goal.deadline,
      start_date: goal.start_date
    }

    # Add debt-specific metrics
    if goal.type_debt_payoff?
      @metrics.merge!(
        starting_debt_amount: goal.starting_debt_amount.to_f,
        current_debt_remaining: (goal.starting_debt_amount - goal.current_amount).to_f,
        debt_strategy: goal.debt_strategy
      )
    end
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name
    }
  end
end
