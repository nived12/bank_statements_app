# Preview all emails at http://localhost:3000/rails/mailers/reminder_mailer_mailer
class ReminderMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/reminder_mailer_mailer/debt_payment_reminder
  def debt_payment_reminder
    ReminderMailer.debt_payment_reminder
  end

  # Preview this email at http://localhost:3000/rails/mailers/reminder_mailer_mailer/payment_overdue
  def payment_overdue
    ReminderMailer.payment_overdue
  end

  # Preview this email at http://localhost:3000/rails/mailers/reminder_mailer_mailer/savings_contribution_reminder
  def savings_contribution_reminder
    ReminderMailer.savings_contribution_reminder
  end
end
