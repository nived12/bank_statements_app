# frozen_string_literal: true

module Trial
  # Emails users approaching the end of their free trial, at three milestones:
  # 7, 3 and 1 days remaining.
  #
  # iOS ships without StoreKit IAP, so the app itself offers no purchase path
  # (Guideline 3.1.1). This email is the route to the web subscription page.
  #
  # Idempotency is carried by users.trial_reminder_stage, which holds the
  # milestone of the last email sent and only ever decreases. Consequences:
  #   - each milestone fires at most once
  #   - a missed run degrades instead of failing (skip day 7 → the user still
  #     gets day 3) because selection is a window, not an exact day
  #   - no retroactive sends: a user first seen with 2 days left gets the
  #     3-day email, never the 7-day one
  class ReminderJob < ApplicationJob
    queue_as :default

    # Ascending: #find returns the SMALLEST milestone the user now qualifies
    # for. 5 days left => 7, 2 => 3, 0 => 1. Reversing this order silently
    # sends every user the 7-day email, so it is covered directly by specs.
    MILESTONES = [ 1, 3, 7 ].freeze

    def perform
      due_users.find_each do |user|
        process(user)
      rescue StandardError => e
        Rails.logger.error("[Trial::ReminderJob] user=#{user.id} #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end

    private

    def due_users
      # Window starts at the beginning of today, not Time.current: a trial
      # expiring at 03:00 is already past when the job runs at 09:00, and that
      # last-day user is precisely who the final email is for.
      User.kept
          .where(trial_ends_at: Time.current.beginning_of_day..MILESTONES.max.days.from_now)
          .where.not(confirmed_at: nil)
          .includes(:pay_subscriptions)
    end

    def process(user)
      return if user.active_paid_subscription?

      days_left = (user.trial_ends_at.to_date - Date.current).to_i
      milestone = MILESTONES.find { |m| days_left <= m }
      return if milestone.nil?
      return if user.trial_reminder_stage.present? && user.trial_reminder_stage <= milestone

      ReminderMailer.trial_ending(user, days_left).deliver_later
      user.update_column(:trial_reminder_stage, milestone)
    end
  end
end
