class ReminderMailer < ApplicationMailer
  # NOTE: Email sending is currently disabled
  # This infrastructure will be enabled when User Notification Preferences feature is implemented
  # Push notifications will also be added at that time

  # Remind user about upcoming debt payment
  # @param debt [Debt] The debt with upcoming payment
  # @param due_date [Date] The payment due date
  # @param amount [Decimal] The payment amount
  def debt_payment_reminder(debt, due_date, amount)
    @debt = debt
    @due_date = due_date
    @amount = amount
    @user = debt.user
    @days_until_due = (due_date - Date.current).to_i

    # Include recommended debt info if part of a goal with strategy
    if debt.goals.any? { |g| g.type_debt_payoff? && g.debt_strategy.present? }
      @goal = debt.goals.find { |g| g.type_debt_payoff? && g.debt_strategy.present? }
      @recommendation = @goal.recommended_debt
    end

    mail(
      to: @user.email,
      subject: I18n.t("reminder_mailer.debt_payment_reminder.subject", debt_name: @debt.name, days: @days_until_due)
    )
  end

  # Remind user about overdue debt payment
  # @param debt [Debt] The debt with overdue payment
  def payment_overdue(debt)
    @debt = debt
    @user = debt.user
    @amount = debt.target_payment_amount || debt.minimum_payment

    mail(
      to: @user.email,
      subject: I18n.t("reminder_mailer.payment_overdue.subject", debt_name: @debt.name)
    )
  end

  # Remind user about savings contribution goal
  # @param saving [Saving] The saving with contribution target
  # @param progress [Hash] Current month progress data
  def savings_contribution_reminder(saving, progress)
    @saving = saving
    @progress = progress
    @user = saving.user
    @shortfall = progress[:target] - progress[:achieved]
    @days_left = (Date.current.end_of_month - Date.current).to_i

    mail(
      to: @user.email,
      subject: I18n.t("reminder_mailer.savings_contribution_reminder.subject", saving_name: @saving.name)
    )
  end
end
