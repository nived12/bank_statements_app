# frozen_string_literal: true

##
# Recurring::DueProcessor
#
# Single class handling all due-date transitions on a recurring series.
# - confirm: creates a transaction and advances next_due_date
# - skip:    advances next_due_date only
# - notify_if_due: idempotent push notification (one per day per series)
#
class Recurring::DueProcessor
  class NoBankAccountError < StandardError; end

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
    return false if @series.last_notified_on == Date.current

    Notifications::PushJob.perform_later(
      user_id: @series.user_id,
      title:   I18n.t("recurring.notifications.due_title", name: @series.name),
      body:    I18n.t(
        "recurring.notifications.due_body",
        amount: ActiveSupport::NumberHelper.number_to_currency(@series.expected_amount, unit: "$")
      ),
      data:    { type: "recurring_due", recurring_series_id: @series.id },
      notification_type: :recurring_due
    )
    @series.update_column(:last_notified_on, Date.current)
    true
  end

  private

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
