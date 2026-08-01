# frozen_string_literal: true

module Notifications
  # Expo tickets only mean "queued" — an uninstalled device still returns "ok".
  # Receipts carry the real outcome, and are the only place a delivery failure
  # is observable. Enqueued by PushSender after RECEIPT_DELAY.
  class ReceiptJob < ApplicationJob
    queue_as :low_priority

    # Stub the literal in specs, never this constant.
    EXPO_RECEIPTS_URL = "https://exp.host/--/api/v2/push/getReceipts"

    BATCH_SIZE = 1000

    # user_id scopes deactivation: push_token is unique per user, not globally.
    def perform(user_id, ticket_map)
      return if ticket_map.blank?

      user = User.find_by(id: user_id)
      return if user.nil?

      ticket_map.keys.each_slice(BATCH_SIZE) do |ids|
        process_batch(user, ids, ticket_map)
      end
    end

    private

    def process_batch(user, ids, ticket_map)
      response = post_receipts(ids)

      unless response.is_a?(Net::HTTPSuccess)
        report("HTTP #{response.code}: #{response.body.to_s.truncate(200)}")
        return
      end

      receipts = JSON.parse(response.body)["data"] || {}
      dead = []

      receipts.each do |ticket_id, receipt|
        next unless receipt["status"] == "error"

        token = ticket_map[ticket_id]
        error = receipt.dig("details", "error")

        if error == "DeviceNotRegistered"
          dead << token
        else
          # MessageTooBig, MismatchSenderId etc — not the device's fault, token stays.
          report("#{error || "unknown"} for #{token}: #{receipt["message"]}")
        end
      end

      deactivate(user, dead)
    rescue JSON::ParserError
      report("unparseable receipts body: #{response.body.to_s.truncate(200)}")
    end

    # One UPDATE per batch, not per token — a full batch is 1000 receipts.
    def deactivate(user, tokens)
      return if tokens.empty?

      Rails.logger.info("[ReceiptJob] deactivating #{tokens.size} unregistered token(s)")
      user.devices.where(push_token: tokens).update_all(active: false)
    end

    def post_receipts(ids)
      uri = URI(EXPO_RECEIPTS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
      token = ENV["EXPO_ACCESS_TOKEN"]
      headers["Authorization"] = "Bearer #{token}" if token.present?

      http.post(uri.path, { ids: ids }.to_json, headers)
    end

    def report(detail)
      message = "[ReceiptJob] #{detail}"
      Rails.logger.error(message)
      Sentry.capture_message(message, level: :error) if defined?(Sentry)
    end
  end
end
