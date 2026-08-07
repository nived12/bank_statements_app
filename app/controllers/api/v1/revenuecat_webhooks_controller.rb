# frozen_string_literal: true

module Api
  module V1
    # Receives App Store subscription events from RevenueCat and keeps
    # ApplePremiumSubscription current. Called by RevenueCat, never by the app, so
    # it carries no JWT — the shared secret set in the RevenueCat dashboard is the
    # only credential.
    #
    # Everything it can recognise is answered 200. RevenueCat retries any non-2xx
    # indefinitely, and a permanent condition (deleted user, event type we do not
    # model) would retry forever without ever succeeding.
    class RevenuecatWebhooksController < ActionController::API
      before_action :authenticate_revenuecat!

      def create
        Subscriptions::AppleEntitlementSyncer.call(event: params[:event]&.to_unsafe_h || {})
        head :ok
      end

      private

      def authenticate_revenuecat!
        expected = ENV["REVENUECAT_WEBHOOK_AUTH_HEADER"]
        # A blank secret must fail closed. Comparing blank to blank would otherwise
        # leave entitlement writes open the moment the env var went missing.
        return head :unauthorized if expected.blank?

        provided = request.headers["Authorization"].to_s
        return if ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        head :unauthorized
      end
    end
  end
end
