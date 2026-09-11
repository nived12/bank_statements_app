# frozen_string_literal: true

# Gate for the Sidekiq dashboard, which ships Delete All, Retry All and Kill
# buttons and displays job arguments. It was mounted unauthenticated and
# publicly reachable until 2026-09-11.
#
# Basic auth rather than a session check on purpose: the dashboard reads Redis
# only, so a gate that queries Postgres would lock us out exactly when the
# database is the reason jobs are piling up.
module SidekiqWebAuth
  class << self
    # Read per call, not at boot, so rotating the password needs no restart.
    def authorized?(user, password)
      expected_user = ENV["SIDEKIQ_USER"]
      expected_password = ENV["SIDEKIQ_PASSWORD"]
      return false if expected_user.blank? || expected_password.blank?

      # & not &&: short-circuiting would leak which half was wrong via timing.
      secure_compare(user, expected_user) & secure_compare(password, expected_password)
    end

    private

    def secure_compare(given, expected)
      ActiveSupport::SecurityUtils.secure_compare(given.to_s, expected)
    end
  end
end
