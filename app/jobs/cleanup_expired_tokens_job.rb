# frozen_string_literal: true

##
# CleanupExpiredTokensJob
# Cleans up expired refresh tokens from the database
#
# This job runs daily to clear out expired refresh_token_expires_at
# entries, helping maintain database hygiene and security.
#
# Scheduled via config/recurring.yml
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
