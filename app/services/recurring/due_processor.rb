# frozen_string_literal: true

##
# Recurring::DueProcessor
#
# Single class handling all due-date transitions on a recurring series.
# - confirm: creates a transaction and advances next_due_date
# - skip:    advances next_due_date only
# - notify_if_due: throttled push notification (see constants below)
#
class Recurring::DueProcessor
  class NoBankAccountError < StandardError; end

  # next_due_date only advances on #confirm or #skip, so an overdue series stays
  # "due" forever. Without these two bounds a series the user ignores would push
  # every single day, indefinitely. Latent until 2026-07-31 — nothing scheduled
  # DailyDueJob before then, so it had never run in production.

  # Minimum days between reminders for the same series.
  RENOTIFY_AFTER_DAYS = 3

  # Stop reminding once a series is this far past due — at that point it's
  # abandoned data, not an actionable reminder, and "due today" copy is a lie.
  ABANDONED_AFTER_DAYS = 30

  def initialize(series)
    @series = series
  end

  def confirm(attrs = {})
    bank_account = attrs[:bank_account] || @series.user.bank_accounts.first
    raise NoBankAccountError if bank_account.nil?

    transaction = build_transaction(attrs.merge(bank_account: bank_account))
    @series.with_lock do
      transaction.save!
      @series.update!(
        next_due_date: @series.next_due_date + @series.interval_days.days,
        last_charged_at: transaction.date,
        occurrences_count: @series.occurrences_count + 1,
        confirmed_at: @series.confirmed_at || Time.current
      )
    end
    transaction
  end

  def skip
    @series.with_lock do
      @series.update!(next_due_date: @series.next_due_date + @series.interval_days.days)
    end
    @series
  end

  def notify_if_due
    return false unless @series.status == "active"
    return false if @series.next_due_date > Date.current
    return false if abandoned?
    return false if recently_notified?

    days_overdue = (Date.current - @series.next_due_date).to_i
    scope = days_overdue.zero? ? "due" : "overdue"

    Notifications::PushJob.perform_later(
      user_id: @series.user_id,
      title:   I18n.t("recurring.notifications.#{scope}_title", name: @series.name),
      body:    I18n.t(
        "recurring.notifications.#{scope}_body",
        amount: ActiveSupport::NumberHelper.number_to_currency(@series.expected_amount, unit: "$"),
        count: days_overdue
      ),
      data:    { type: "recurring_due", recurring_series_id: @series.id },
      notification_type: :recurring_due
    )
    @series.update_column(:last_notified_on, Date.current)
    true
  end

  private

  def abandoned?
    @series.next_due_date < ABANDONED_AFTER_DAYS.days.ago.to_date
  end

  def recently_notified?
    @series.last_notified_on.present? &&
      @series.last_notified_on > RENOTIFY_AFTER_DAYS.days.ago.to_date
  end

  def build_transaction(attrs)
    Transaction.new(
      user: @series.user,
      bank_account: attrs[:bank_account],
      category: @series.category,
      transaction_type: @series.transaction_type,
      description: attrs[:description] || @series.name,
      merchant: @series.merchant_hint,
      amount: attrs[:amount] || signed_amount,
      date: attrs[:date] || Date.current,
      recurring_series: @series,
      source: 0 # manual
    )
  end

  def signed_amount
    @series.transaction_type == "income" ? @series.expected_amount.abs : -@series.expected_amount.abs
  end
end
