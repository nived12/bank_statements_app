# frozen_string_literal: true

# Sidekiq's client process does not load sidekiq/api, and without it this raises
# NameError at 07:15 in production and nowhere else.
require "sidekiq/api"

# Nothing else watches the dead set. Fourteen mailer jobs sat in it from April
# 2026 to September 2026 with no signal anywhere: :max_retries is 3, so a job
# that exhausts its retries lands there and stops existing.
class DeadSetAlertJob < ApplicationJob
  queue_as :low_priority

  # The dead set holds up to dead_max_jobs (10k). The breakdown only needs
  # enough entries to name the culprit.
  SCAN_LIMIT = 500

  # Sentry groups capture_message by message text, so the count stays out of it:
  # a number here would open a new issue every time the backlog moved.
  MESSAGE = "[DeadSetAlertJob] Sidekiq dead set is not empty"

  def perform
    dead = Sidekiq::DeadSet.new
    total = dead.size
    return if total.zero?

    sample = dead.first(SCAN_LIMIT)
    oldest_at = sample.first&.at&.iso8601

    Rails.logger.error("#{MESSAGE} - #{total} job(s), oldest #{oldest_at}")

    return unless defined?(Sentry)

    Sentry.capture_message(
      MESSAGE,
      level: :error,
      extra: {
        total: total,
        scanned: sample.size,
        oldest_at: oldest_at,
        by_class: breakdown(sample)
      }
    )
  end

  private

  # display_class unwraps the ActiveJob wrapper, so mailers group as
  # "ReminderMailer#trial_ending" rather than all landing under
  # ActionMailer::MailDeliveryJob.
  def breakdown(entries)
    entries.group_by(&:display_class)
           .transform_values(&:size)
           .sort_by { |_klass, count| -count }
           .to_h
  end
end
