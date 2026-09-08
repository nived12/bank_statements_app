# frozen_string_literal: true

# Resend allows 10 requests/second per account, and Trial::ReminderJob enqueues
# its whole audience at 09:00, so the ceiling is reached by ordinary operation
# rather than by a bug. The limit is per account, shared with every other mailer,
# which is why backing off lives here and not in the fan-out loop.
#
# If the "gave up" message below ever appears in Sentry, that is the signal to
# also pace the enqueue — with a measured number rather than a guessed one.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  RATE_LIMIT_ATTEMPTS = 8

  # Not Resend::Error: RateLimitExceededError < ServerError < Error, so widening
  # this would retry 422s forever.
  retry_on Resend::Error::RateLimitExceededError,
    wait: :polynomially_longer,
    attempts: RATE_LIMIT_ATTEMPTS do |job, error|
    # Swallowing discards the mail deliberately. Re-raising here buys three
    # silent Sidekiq retries and then the dead set, which is the failure this
    # whole change exists to stop.
    message = "[MailDeliveryJob] gave up on #{job.arguments.first}##{job.arguments.second} " \
              "after #{RATE_LIMIT_ATTEMPTS} rate-limited attempts: #{error.message}"
    Rails.logger.error(message)
    Sentry.capture_message(message, level: :error) if defined?(Sentry)
  end
end
