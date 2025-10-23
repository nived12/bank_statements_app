# frozen_string_literal: true

##
# Goals::UpdateService
# Service for updating existing goals
# Handles validation, status changes, and business logic
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

    # Handle status changes with special logic
    if status_action_present?
      handle_status_change
    else
      update_goal
    end

    return failure if has_errors?

    # Check if goal should be auto-completed (only for regular updates)
    check_auto_completion if goal.status_active? && !status_action_present?

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
    # Extract association parameters
    saving_ids = goal_params.delete(:saving_ids)
    debt_ids = goal_params.delete(:debt_ids)

    # Update goal attributes
    unless goal.update(goal_params)
      goal.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
      return
    end

    # Update associations if provided
    update_savings_associations(saving_ids) if saving_ids.present?
    update_debts_associations(debt_ids) if debt_ids.present?
  end

  def status_action_present?
    goal_params[:status_action].present?
  end

  def handle_status_change
    case goal_params[:status_action]
    when "complete"
      handle_complete_status
    when "pause"
      update_status("paused")
    when "resume"
      update_status("active")
    when "archive"
      archive_goal
    when "unarchive"
      unarchive_goal
    else
      errors.add(:status_action, "is not valid")
    end
  end

  def handle_complete_status
    force = goal_params[:force].present? && goal_params[:force] == "true"

    # Validate completion requirements unless forced
    unless force
      if goal.type_savings_goal? && goal.current_amount < goal.target_amount
        errors.add(:goal, "has not reached target amount yet (#{goal.current_amount} / #{goal.target_amount})")
        return
      elsif goal.type_debt_payoff?
        remaining_debt = goal.starting_debt_amount - goal.current_amount
        if remaining_debt > goal.target_amount
          errors.add(:goal, "debt has not been paid down to target yet (#{remaining_debt} remaining)")
          return
        end
      end
    end

    goal.complete_goal!
  end

  def update_status(new_status)
    unless goal.update(status: new_status)
      goal.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end

  def archive_goal
    # Discard the goal (sets discarded_at and status to archived via callback)
    unless goal.discard
      errors.add(:goal, "could not be archived")
    end
  rescue => e
    errors.add(:goal, "could not be archived: #{e.message}")
  end

  def unarchive_goal
    # Undiscard the goal (clears discarded_at and restores status via callback)
    unless goal.undiscard
      errors.add(:goal, "could not be unarchived")
    end
  rescue => e
    errors.add(:goal, "could not be unarchived: #{e.message}")
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

  def update_savings_associations(saving_ids)
    # Convert to integers and filter out empty strings
    saving_ids = saving_ids.map(&:to_i).reject(&:zero?)

    # Get current savings
    current_saving_ids = goal.savings.pluck(:id)

    # Find savings to add and remove
    savings_to_add = saving_ids - current_saving_ids
    savings_to_remove = current_saving_ids - saving_ids

    # Add new associations
    savings_to_add.each do |saving_id|
      saving = goal.user.savings.find_by(id: saving_id)
      if saving
        goal.goal_savings.create!(saving: saving)
      end
    end

    # Remove old associations
    savings_to_remove.each do |saving_id|
      goal.goal_savings.where(saving_id: saving_id).destroy_all
    end
  end

  def update_debts_associations(debt_ids)
    # Convert to integers and filter out empty strings
    debt_ids = debt_ids.map(&:to_i).reject(&:zero?)

    # Get current debts
    current_debt_ids = goal.debts.pluck(:id)

    # Find debts to add and remove
    debts_to_add = debt_ids - current_debt_ids
    debts_to_remove = current_debt_ids - debt_ids

    # Add new associations
    debts_to_add.each do |debt_id|
      debt = goal.user.debts.find_by(id: debt_id)
      if debt
        goal.goal_debts.create!(debt: debt)
      end
    end

    # Remove old associations
    debts_to_remove.each do |debt_id|
      goal.goal_debts.where(debt_id: debt_id).destroy_all
    end
  end
end
