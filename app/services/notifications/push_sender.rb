# frozen_string_literal: true

module Notifications
  class PushSender < ApplicationService
    # Expo's documented push endpoint. Do not stub this constant in specs —
    # stub the literal, so a wrong value fails instead of matching itself.
    EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send"

    def initialize(user:, title:, body:, data: {})
      super()
      @user  = user
      @title = title
      @body  = body
      @data  = data
    end

    def call
      devices = @user.devices.active
      return success(sent: 0) if devices.none?

      expo_tokens = devices.where.not(platform: "web").pluck(:push_token)
      web_subscriptions = devices.where(platform: "web").pluck(:push_token)

      sent = 0
      sent += send_expo(expo_tokens) if expo_tokens.any?
      sent += send_web(web_subscriptions) if web_subscriptions.any?

      success(sent: sent)
    rescue StandardError => e
      Rails.logger.error("PushSender error: #{e.message}")
      failure("Push delivery failed: #{e.message}")
    end

    private

    def send_expo(tokens)
      # Expo Push API accepts up to 100 messages per request
      tokens.each_slice(100).sum do |batch|
        messages = batch.map do |token|
          {
            to: token,
            title: @title,
            body: @body,
            sound: "default",
            data: @data
          }
        end

        response = expo_http.post(EXPO_PUSH_URL, messages.to_json, expo_headers)
        handle_expo_response(response, batch)
      end
    end

    def send_web(subscription_jsons)
      vapid_private = ENV["VAPID_PRIVATE_KEY"]
      vapid_public  = ENV["VAPID_PUBLIC_KEY"]
      vapid_subject = ENV.fetch("VAPID_SUBJECT", "mailto:hello@vittio.app")

      return 0 if vapid_private.blank? || vapid_public.blank?

      sent = 0
      subscription_jsons.each do |json_str|
        subscription = JSON.parse(json_str)
        payload = JSON.generate({ title: @title, body: @body, data: @data })

        WebPush.payload_send(
          message: payload,
          endpoint: subscription["endpoint"],
          p256dh: subscription.dig("keys", "p256dh"),
          auth: subscription.dig("keys", "auth"),
          vapid: { subject: vapid_subject, private_key: vapid_private, public_key: vapid_public }
        )
        sent += 1
      rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => e
        Rails.logger.warn("Web push subscription invalid/expired, marking inactive: #{e.message}")
        Device.find_by(push_token: json_str)&.update(active: false)
      rescue StandardError => e
        Rails.logger.error("Web push error: #{e.message}")
      end

      sent
    end

    # Returns the number of messages Expo accepted. A rejected batch must count
    # zero and be reported: when this returned the batch size unconditionally,
    # a 404 endpoint looked identical to a successful send and push silently
    # never worked in production.
    def handle_expo_response(response, tokens)
      unless response.is_a?(Net::HTTPSuccess)
        report_expo_failure("HTTP #{response.code}", tokens.size, response.body.to_s.truncate(200))
        return 0
      end

      results = JSON.parse(response.body).dig("data") || []
      results.each_with_index do |result, i|
        next unless result["status"] == "error" && result["details"]&.dig("error") == "DeviceNotRegistered"

        token = tokens[i]
        Rails.logger.warn("Expo token #{token} no longer registered, deactivating")
        # Scoped to the user: push_token is only unique per user, so an unscoped
        # lookup can deactivate another user's row for the same physical device.
        @user.devices.find_by(push_token: token)&.update(active: false)
      end

      results.count { |result| result["status"] == "ok" }
    rescue JSON::ParserError
      report_expo_failure("unparseable body", tokens.size, response.body.to_s.truncate(200))
      0
    end

    def report_expo_failure(reason, count, body)
      message = "PushSender: Expo rejected #{count} message(s) — #{reason}: #{body}"
      Rails.logger.error(message)
      Sentry.capture_message(message, level: :error) if defined?(Sentry)
    end

    def expo_http
      uri = URI(EXPO_PUSH_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end

    def expo_headers
      headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
      token = ENV["EXPO_ACCESS_TOKEN"]
      headers["Authorization"] = "Bearer #{token}" if token.present?
      headers
    end
  end
end
