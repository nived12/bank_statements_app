# frozen_string_literal: true

##
# Goals::AutoLinkTransactionService
# Automatically links transactions to goals based on matching criteria
# and goal_calculation_settings
#
class Goals::AutoLinkTransactionService < ApplicationService
  def initialize(transaction)
    super()
    @transaction = transaction
  end

  def call
    return success if skip_auto_linking?

    matching_goals = find_matching_goals

    matching_goals.each do |goal|
      auto_link_to_goal(goal)
    end

    success
  end

  private

  attr_reader :transaction

  def skip_auto_linking?
    # Skip if no category or bank account
    return true if transaction.category_id.blank?
    return true if transaction.bank_account_id.blank?

    # Skip if transaction has any manual links (manual linking takes precedence)
    return true if transaction.goal_transactions.where(manual: true).exists?

    false
  end

  def find_matching_goals
    # Active goals with auto_link enabled, matching bank_account + category
    Goal.with_auto_link
        .active
        .where(bank_account_id: transaction.bank_account_id)
        .where(category_id: transaction.category_id)
        .where("start_date <= ? AND deadline >= ?", transaction.date, transaction.date)
  end

  def auto_link_to_goal(goal)
    # Use Goal model's calculate_amount_for_transaction method
    amount_to_apply = goal.calculate_amount_for_transaction(transaction)

    # Skip if amount is nil (ignore setting) or zero
    return if amount_to_apply.nil? || amount_to_apply.zero?

    # Use existing LinkTransactionService
    result = Goals::LinkTransactionService.call(
      goal,
      transaction,
      amount_to_apply, # Can be positive or negative based on goal_calculation_settings
      notes: "Auto-linked",
      manual: false
    )

    # Log errors but don't fail the whole operation
    unless result.success?
      Rails.logger.warn(
        "Failed to auto-link transaction #{transaction.id} to goal #{goal.id}: " \
        "#{result.errors.full_messages.join(", ")}"
      )
    end
  end
end
