# frozen_string_literal: true

##
# CleanupExpiredTokensJob
# Cleans up expired refresh tokens from the database
#
# This job runs daily to clear out expired refresh_token_expires_at
# entries, helping maintain database hygiene and security.
#
# Scheduled weekly via config/schedule.yml (sidekiq-cron).
# Runs on the low_priority queue, which must stay listed in config/sidekiq.yml
# or the job is enqueued and never processed.
#
class CleanupExpiredTokensJob < ApplicationJob
  queue_as :low_priority

  def perform
    # The first condition already filters out nulls, no need for .where.not
    expired_count = User.where("refresh_token_expires_at < ?", Time.current)
                        .update_all(refresh_token_expires_at: nil)

    Rails.logger.info "Cleaned up #{expired_count} expired refresh tokens"
  end
end
