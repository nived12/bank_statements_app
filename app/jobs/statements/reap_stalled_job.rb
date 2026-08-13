# Fails out statement files whose job died mid-run (OOM, SIGKILL, host loss),
# leaving a row stuck in `processing` that the user can neither see nor retry.
# Marks failed rather than re-enqueueing, since a still-live job would otherwise
# import the same transactions twice.
module Statements
  class ReapStalledJob < ApplicationJob
    queue_as :low_priority

    # A live job touches updated_at when it writes usage_metadata, so a slow but
    # healthy run keeps resetting this clock.
    STALE_AFTER = 30.minutes

    def perform
      stalled = StatementFile.processing.where(updated_at: ..STALE_AFTER.ago)

      stalled.find_each { |statement_file| reap(statement_file) }
    end

    private

    def reap(statement_file)
      # Read before the update, which overwrites it with the reap time.
      stalled_since = statement_file.updated_at

      statement_file.update!(
        status: :error,
        error_message: "processing_interrupted: worker terminated before completion",
        processed_at: Time.current
      )

      Rails.logger.warn(
        "[reap_stalled] statement #{statement_file.id} (user #{statement_file.user_id}) " \
        "stuck in processing since #{stalled_since.utc.iso8601} — marked error"
      )

      if defined?(Sentry)
        Sentry.capture_message(
          "Statement processing stalled",
          level: :warning,
          extra: { statement_file_id: statement_file.id, user_id: statement_file.user_id }
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      # One unsaveable row must not stop the rest from being reaped.
      Rails.logger.error("[reap_stalled] statement #{statement_file.id} could not be updated: #{e.message}")
    end
  end
end
