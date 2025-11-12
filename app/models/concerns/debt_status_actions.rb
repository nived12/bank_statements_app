# frozen_string_literal: true

##
# DebtStatusActions
# Handles status changes and related actions for debts
#
module DebtStatusActions
  extend ActiveSupport::Concern

  # Action: Mark debt as paid off
  def mark_paid_off!
    update!(
      status: "paid_off",
      current_balance: 0
    )
  end

  # Action: Pause debt
  def pause!
    update!(status: "paused")
  end

  # Action: Resume debt
  def resume!
    update!(status: "active")
  end

  # Action: Archive debt
  def archive!
    update!(status: "archived")
  end
end
