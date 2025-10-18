# frozen_string_literal: true

##
# Goals::LinkTransactionService
# Service for linking a transaction to a goal
# Supports partial amounts and multiple goals per transaction
#
class Goals::LinkTransactionService < ApplicationService
  def initialize(goal, transaction, amount_applied, notes: nil)
    super()
    @goal = goal
    @transaction = transaction
    @amount_applied = amount_applied
    @notes = notes
  end

  def call
    validate_params
    return failure if has_errors?

    link_transaction
    return failure if has_errors?

    # Check if goal should be auto-completed
    check_goal_completion

    success(goal_transaction)
  end

  private

  attr_reader :goal, :transaction, :amount_applied, :notes, :goal_transaction

  def validate_params
    if goal.blank?
      errors.add(:goal, "must be present")
      return
    end

    if transaction.blank?
      errors.add(:transaction, "must be present")
      return
    end

    if amount_applied.blank? || amount_applied.to_f <= 0
      errors.add(:amount_applied, "must be greater than 0")
    end

    # Check if already linked
    if GoalTransaction.exists?(goal: goal, transaction_id: transaction.id)
      errors.add(:base, "Transaction is already linked to this goal")
    end

    # Validate goal is not archived or completed
    if goal.status_archived?
      errors.add(:goal, "cannot link transactions to archived goals")
    end
  end

  def link_transaction
    @goal_transaction = GoalTransaction.new(
      goal: goal,
      txn: transaction,
      amount_applied: amount_applied,
      notes: notes
    )

    unless goal_transaction.save
      goal_transaction.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end

  def check_goal_completion
    goal.reload

    return unless goal.status_active?

    if goal.type_savings_goal? && goal.current_amount >= goal.target_amount
      goal.complete_goal!
    elsif goal.type_debt_payoff?
      remaining_debt = goal.starting_debt_amount - goal.current_amount
      if remaining_debt <= goal.target_amount
        goal.complete_goal!
      end
    end
  end

  def context_for_logging
    {
      goal_id: goal&.id,
      goal_name: goal&.name,
      transaction_id: transaction&.id,
      amount_applied: amount_applied
    }
  end
end
