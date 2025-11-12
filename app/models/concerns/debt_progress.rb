# frozen_string_literal: true

##
# DebtProgress
# Handles debt progress tracking and status calculations
#
module DebtProgress
  extend ActiveSupport::Concern

  # Calculate progress percentage (amount paid down)
  def progress_percentage
    return 100 if original_amount.blank? || original_amount.zero?
    return 0 if current_balance >= original_amount

    total_paid = original_amount - current_balance
    ((total_paid.to_f / original_amount.to_f) * 100).round(2)
  end

  # Calculate amount paid down
  def amount_paid
    return 0 if original_amount.blank?

    original_amount - current_balance
  end

  # Calculate amount remaining to pay off
  def amount_remaining
    current_balance
  end

  # Check if debt is on track (simplified version)
  def on_track?
    return true if status_paid_off?

    current_balance >= 0 # For now, any positive balance is "on track"
  end

  # Calculate priority order based on goal's debt strategy
  def priority_order(goal)
    return unless goal&.debt_strategy.present?

    ordered_debts = case goal.debt_strategy
    when "snowball"
      goal.debts.active.order(:current_balance)
    when "avalanche"
      goal.debts.active.order(interest_rate: :desc)
    end

    ordered_debts.pluck(:id).index(id)&.+ 1
  end

  # Check if this debt has the highest priority for a specific goal
  def is_highest_priority?(goal)
    priority_order(goal) == 1
  end
end
