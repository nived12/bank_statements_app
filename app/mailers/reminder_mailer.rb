class ReminderMailer < ApplicationMailer
  # NOTE: The debt/savings reminders below are built but NOT sent — every call site in
  # Reminders::GenerateRemindersService is commented out. See that class for why.
  # trial_ending IS live and is sent by Trial::ReminderJob.

  # Notify a user that their free trial is ending, at 7 / 3 / 1 days remaining.
  # One view covers all three; @days_left drives the subject and urgency copy.
  #
  # Sent in :es — users have no persisted locale (LocaleConcern reads request
  # params only, and a background job has no request) and es-MX is the primary market.
  #
  # @param user [User]
  # @param days_left [Integer] whole days until trial_ends_at
  def trial_ending(user, days_left)
    @user = user
    @days_left = days_left
    @trial_ends_at = user.trial_ends_at
    @subscription_url = subscription_url
    @unsubscribe_url = unsubscribe_url(token: user.generate_token_for(:email_unsubscribe))
    # Explicit variants rather than i18n pluralization: Rails' default rule only
    # distinguishes one/other, so "0 días" would read wrong for a same-day send.
    @variant = case days_left
    when ..0 then "today"
    when 1 then "tomorrow"
    else "days"
    end

    # RFC 8058: lets Gmail and Apple Mail render their own Unsubscribe button and
    # POST to it directly. This is the header bulk-sender reputation is judged on —
    # the in-body link alone does not satisfy it.
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    I18n.with_locale(:es) do
      mail(
        to: @user.email,
        subject: I18n.t("reminder_mailer.trial_ending.subject.#{@variant}", count: @days_left)
      )
    end
  end

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
