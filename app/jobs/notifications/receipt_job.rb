# frozen_string_literal: true

module Notifications
  ##
  # Notifications::ReceiptJob
  #
  # Expo's send response returns *tickets*, which only mean "queued" — a token
  # whose app has been uninstalled still gets status "ok". The real outcome
  # arrives later as a *receipt*, and it is the only place a delivery failure is
  # ever visible: without this job, a push that Expo accepts and APNs/FCM drops
  # is completely silent.
  #
  # Enqueued by PushSender with a delay (see PushSender::RECEIPT_DELAY). The
  # ticket => token map rides in the job arguments rather than a table — Sidekiq
  # already persists args in Redis, and Expo keeps receipts for 24 hours, so
  # there is nothing worth a migration here.
  #
  class ReceiptJob < ApplicationJob
    queue_as :low_priority

    # Do not stub this constant in specs — stub the literal, so a wrong value
    # fails instead of matching itself.
    EXPO_RECEIPTS_URL = "https://exp.host/--/api/v2/push/getReceipts"

    # Expo's documented cap per request.
    BATCH_SIZE = 1000

    # @param user_id [Integer] scopes deactivation; push_token is unique only
    #   per user, so an unscoped lookup can hit another user's row for the same
    #   physical device.
    # @param ticket_map [Hash{String=>String}] Expo ticket id => push token
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
      receipts.each do |ticket_id, receipt|
        next unless receipt["status"] == "error"

        handle_error(user, ticket_map[ticket_id], receipt)
      end
    rescue JSON::ParserError
      report("unparseable receipts body: #{response.body.to_s.truncate(200)}")
    end

    def handle_error(user, token, receipt)
      error = receipt.dig("details", "error")

      if error == "DeviceNotRegistered"
        Rails.logger.info("[ReceiptJob] #{token} unregistered, deactivating")
        user.devices.find_by(push_token: token)&.update(active: false)
      else
        # MessageTooBig, MessageRateExceeded, MismatchSenderId, InvalidCredentials.
        # None are the device's fault, so the token stays active.
        report("#{error || "unknown"} for #{token}: #{receipt["message"]}")
      end
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
