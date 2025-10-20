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
    amount_to_apply = calculate_amount_to_apply(goal)

    # Skip if amount is zero or ignore
    return if amount_to_apply.nil? || amount_to_apply.zero?

    # Use existing LinkTransactionService
    result = Goals::LinkTransactionService.call(
      goal,
      transaction,
      amount_to_apply.abs, # LinkTransactionService expects positive value
      notes: "Auto-linked"
    )

    # Log errors but don't fail the whole operation
    unless result.success?
      Rails.logger.warn(
        "Failed to auto-link transaction #{transaction.id} to goal #{goal.id}: " \
        "#{result.errors.full_messages.join(", ")}"
      )
    end
  end

  def calculate_amount_to_apply(goal)
    settings = goal.goal_calculation_settings || {}
    tx_type = map_transaction_type_to_setting_key(transaction.transaction_type)

    # Get the setting for this transaction type
    setting = settings[tx_type]

    return nil if setting.nil? || setting == "ignore"

    case setting
    when "positive"
      transaction.amount.abs
    when "negative"
      -transaction.amount.abs
    else
      nil
    end
  end

  def map_transaction_type_to_setting_key(transaction_type)
    case transaction_type
    when "income"
      "income"
    when "fixed_expense", "variable_expense"
      "expense"
    when "transfer_in"
      "transfer_in"
    when "transfer_out"
      "transfer_out"
    else
      transaction_type
    end
  end
end
