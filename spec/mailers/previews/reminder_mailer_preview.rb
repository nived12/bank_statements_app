# Preview all emails at http://localhost:3000/rails/mailers/reminder_mailer
#
# Uses in-memory records so previews work against an empty database.
class ReminderMailerPreview < ActionMailer::Preview
  def debt_payment_reminder
    ReminderMailer.debt_payment_reminder(sample_debt, Date.current + 7, 1_850.00)
  end

  def payment_overdue
    ReminderMailer.payment_overdue(sample_debt)
  end

  def savings_contribution_reminder
    ReminderMailer.savings_contribution_reminder(
      sample_saving,
      { target: 5_000.00, achieved: 3_200.00, percentage: 64 }
    )
  end

  # Trial reminders — one preview per milestone, since the copy differs.
  def trial_ending_7_days
    ReminderMailer.trial_ending(sample_user(trial_in: 7), 7)
  end

  def trial_ending_3_days
    ReminderMailer.trial_ending(sample_user(trial_in: 3), 3)
  end

  def trial_ending_tomorrow
    ReminderMailer.trial_ending(sample_user(trial_in: 1), 1)
  end

  def trial_ending_today
    ReminderMailer.trial_ending(sample_user(trial_in: 0), 0)
  end

  private

  def sample_user(trial_in: 7)
    User.new(
      first_name: "Ana",
      last_name: "García",
      email: "ana@example.com",
      trial_ends_at: trial_in.days.from_now
    )
  end

  def sample_debt
    Debt.new(
      name: "Tarjeta BBVA",
      user: sample_user,
      minimum_payment: 1_850.00,
      target_payment_amount: 2_500.00
    )
  end

  def sample_saving
    Saving.new(name: "Fondo de emergencia", user: sample_user)
  end
end
