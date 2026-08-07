# frozen_string_literal: true

module Trial
  # Emails users at 7, 3 and 1 days left on their trial. iOS has no in-app
  # purchase path (Guideline 3.1.1), so this is the route to the web upgrade.
  #
  # users.trial_reminder_stage holds the last milestone sent and only ever
  # decreases: each fires once, a missed run degrades to the next milestone
  # rather than skipping the user, and nothing is sent retroactively.
  class ReminderJob < ApplicationJob
    queue_as :default

    # Ascending — #find returns the smallest milestone reached (5 days => 7,
    # 2 => 3). Reversing this sends everyone the 7-day email.
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
      # Whole days on both ends so the window matches days_left (0..7) and does
      # not drift with the hour the job runs. Trials expiring earlier today
      # still count — that user's last day is exactly when to mail them.
      User.kept
          .where(trial_ends_at: Time.current.beginning_of_day..MILESTONES.max.days.from_now.end_of_day)
          .where.not(confirmed_at: nil)
          .includes(:pay_subscriptions, :user_setting, :apple_premium_subscription)
    end

    def process(user)
      return if user.active_paid_subscription?
      # Opted out via the unsubscribe link. Checked before the stage is stamped so
      # a later opt-in still receives the milestones that have not passed yet.
      # A missing settings row means "never configured", not "opted out" — every other
      # preference defaults to true, and this is the only conversion path iOS has.
      return if user.user_setting && !user.user_setting.notify_trial_reminders

      days_left = (user.trial_ends_at.to_date - Date.current).to_i
      milestone = MILESTONES.find { |m| days_left <= m }
      return if milestone.nil?
      return if user.trial_reminder_stage.present? && user.trial_reminder_stage <= milestone

      ReminderMailer.trial_ending(user, days_left).deliver_later
      user.update_column(:trial_reminder_stage, milestone)
    end
  end
end
