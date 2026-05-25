# frozen_string_literal: true

# Thin wrapper around posthog-ruby.
# - No-op when POSTHOG_API_KEY is not set (dev/test).
# - Never raises — analytics must never crash the app.
# - EU cloud host for LFPDPPP compliance.
module Analytics
  def self.capture(distinct_id:, event:, properties: {})
    return unless client

    client.capture(
      distinct_id: distinct_id.to_s,
      event: event,
      properties: properties
    )
  rescue StandardError => e
    Rails.logger.warn("[Analytics] capture failed for #{event}: #{e.message}")
  end

  def self.client
    @client ||= begin
      return nil if ENV["POSTHOG_API_KEY"].blank?

      ::PostHog::Client.new(
        api_key: ENV["POSTHOG_API_KEY"],
        host: "https://eu.i.posthog.com",
        on_error: proc { |_status, msg| Rails.logger.warn("[Analytics] #{msg}") }
      )
    end
  end
end
