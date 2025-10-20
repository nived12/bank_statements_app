# frozen_string_literal: true

##
# Transactions::Concerns::GoalLinkable
# Shared concern for manual goal linking in transaction services
#
module Transactions::Concerns::GoalLinkable
  extend ActiveSupport::Concern

  private

  # Manually link a transaction to a goal
  # This method doesn't fail the transaction creation/update if goal linking fails
  def link_to_goal(transaction, goal_id)
    goal = Current.user.goals.find_by(id: goal_id)

    unless goal
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: goal #{goal_id} not found")
      return
    end

    # Skip if goal is not active
    unless goal.status_active?
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: goal #{goal.id} is not active")
      return
    end

    # Check if already manually linked to this goal
    existing_link = transaction.goal_transactions.find_by(goal_id: goal.id, manual: true)
    return if existing_link.present?

    # Calculate amount based on goal's settings
    amount_to_apply = goal.calculate_amount_for_transaction(transaction)

    # If amount is nil (ignore setting), skip linking
    # But log a warning since user explicitly requested it
    if amount_to_apply.nil?
      Rails.logger.warn(
        "Transaction #{transaction.id} not linked to goal #{goal.id}: " \
        "transaction type #{transaction.transaction_type} is set to 'ignore' in goal settings"
      )
      return
    end

    # Link the transaction
    result = Goals::LinkTransactionService.call(
      goal,
      transaction,
      amount_to_apply,
      notes: "Manually linked",
      manual: true
    )

    unless result.success?
      # Log linking errors but don't fail the transaction creation/update
      Rails.logger.error("Failed to link transaction #{transaction.id} to goal #{goal.id}: #{result.errors.full_messages.join(", ")}")
    end
  end
end
