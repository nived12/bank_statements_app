# frozen_string_literal: true

module Recurring
  class DailyDueJob < ApplicationJob
    queue_as :default

    def perform
      RecurringSeries.active.due_on_or_before(Date.current).find_each do |series|
        ::Recurring::DueProcessor.new(series).notify_if_due
      rescue StandardError => e
        Rails.logger.error("[Recurring::DailyDueJob] series=#{series.id} #{e.class}: #{e.message}")
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end
  end
end
