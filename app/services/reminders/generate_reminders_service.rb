# frozen_string_literal: true

module Reminders
  # GenerateRemindersService - Single service to generate ALL reminders (debts + savings)
  #
  # Returns a hash of reminder data. It does NOT persist anything (there is no
  # Reminder model) and does NOT send email — the ReminderMailer calls below are
  # commented out, so nothing here reaches a user today.
  #
  # The notification-preference gate these were waiting on DOES now exist
  # (UserSetting#notify_debt_reminders, the settings API, and the mobile
  # notification-preferences screen). Enabling them is a deferred PRODUCT
  # decision, not a missing dependency: switching them on starts recurring mail
  # to every user with a debt or savings goal. Wrap each call in the matching
  # preference check when that decision is made.
  class GenerateRemindersService < ApplicationService
    def initialize(user: nil)
      super()
      @user = user
      @reminders = {
        debt_payments: [],
        savings_contributions: []
      }
    end

    def call
      generate_debt_payment_reminders
      generate_savings_contribution_reminders

      success(@reminders)
    end

    private

    def generate_debt_payment_reminders
      debts_scope = @user.present? ? @user.debts : Debt
      active_debts = debts_scope.active.with_due_date

      active_debts.each do |debt|
        days_until_due = debt.payment_due_in_days
        next if days_until_due.blank?

        # Generate reminders for 7, 3, and 1 days before due date
        if [7, 3, 1, 0].include?(days_until_due)
          @reminders[:debt_payments] << {
            debt: debt,
            due_date: debt.calculate_next_due_date,
            amount: debt.target_payment_amount || debt.minimum_payment,
            days_until_due: days_until_due,
            user: debt.user
          }

          # Deliberately not sent — see the class comment above.
          # ReminderMailer.debt_payment_reminder(debt, debt.calculate_next_due_date, amount).deliver_later
        elsif debt.payment_overdue?
          # Overdue payment
          @reminders[:debt_payments] << {
            debt: debt,
            due_date: debt.calculate_next_due_date,
            amount: debt.target_payment_amount || debt.minimum_payment,
            days_until_due: days_until_due,
            overdue: true,
            user: debt.user
          }

          # Deliberately not sent — see the class comment above.
          # ReminderMailer.payment_overdue(debt).deliver_later
        end
      end
    end

    def generate_savings_contribution_reminders
      savings_scope = @user.present? ? @user.savings : Saving
      active_savings = savings_scope.active.with_contribution_target

      active_savings.each do |saving|
        progress = saving.current_month_progress
        days_left_in_month = (Date.current.end_of_month - Date.current).to_i

        # Remind if behind target and approaching end of month (within 7 days)
        if days_left_in_month <= 7 && saving.behind_this_month?
          @reminders[:savings_contributions] << {
            saving: saving,
            progress: progress,
            days_left: days_left_in_month,
            shortfall: progress[:target] - progress[:achieved],
            user: saving.user
          }

          # Deliberately not sent — see the class comment above.
          # ReminderMailer.savings_contribution_reminder(saving, progress).deliver_later
        end
      end
    end
  end
end
