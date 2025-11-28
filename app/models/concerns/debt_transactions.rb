# frozen_string_literal: true

##
# DebtTransactions
# Handles transaction-related calculations and linking
#
module DebtTransactions
  extend ActiveSupport::Concern

  # Recalculate current_balance from linked transactions
  def recalculate_current_balance!
    total_paid = debt_transactions.sum(:amount_applied)
    new_balance = original_amount.to_f - total_paid
    new_balance = [new_balance, 0].max # Don't go below zero

    update_column(:current_balance, new_balance)

    # Auto-update status based on balance
    if new_balance.zero? && status_active?
      # Mark as paid off when balance reaches zero
      mark_paid_off!
    elsif new_balance.positive? && status_paid_off?
      # Reactivate if balance goes back above zero (e.g., manual adjustment or transaction removal)
      update_column(:status, "active")
    end
  end

  # Calculate amount to apply for a transaction based on calculation_settings
  # Returns positive, negative, or nil (for ignore)
  def calculate_amount_for_transaction(transaction)
    settings = calculation_settings || {}
    tx_type = map_transaction_type_to_setting_key(transaction.transaction_type)

    # Get the setting for this transaction type
    setting = settings[tx_type]

    return if setting.nil? || setting == "ignore"

    case setting
    when "positive"
      transaction.amount.abs
    when "negative"
      -transaction.amount.abs
    else
      nil
    end
  end

  # Check if transaction date is within any goal's active period
  def transaction_within_date_range?(transaction)
    return true if goals.empty? # No goals, accept all dates
    return false if transaction.date.blank?

    goals.any? { |goal| transaction.date >= goal.start_date && transaction.date <= goal.deadline }
  end

  private

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
