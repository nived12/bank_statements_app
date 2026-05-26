# frozen_string_literal: true

module Users
  # Archives a user from the UI. Soft-delete via Discard — preserves all
  # personal data so it can be restored by support if needed.
  #
  # Hard deletion (LFPDPPP Art. 22 right-to-erasure on explicit request)
  # is reserved for Users::Destroyer, invoked only via the rake task.
  class Archiver < ApplicationService
    def initialize(user:)
      super()
      @user = user
    end

    def call
      return success if @user.discarded?

      ActiveRecord::Base.transaction do
        cancel_stripe_subscription
        @user.discard!
        rotate_jti
      end

      ::Analytics.capture(distinct_id: @user.id, event: "user_archived")
      success
    rescue => e
      Rails.logger.error("Users::Archiver failed for user #{@user.id}: #{e.class}: #{e.message}")
      failure(e.message)
    end

    private

    def cancel_stripe_subscription
      sub = @user.current_paid_subscription
      return unless sub

      sub.cancel_now!
    rescue => e
      Rails.logger.warn("Users::Archiver: Stripe cancellation failed for user #{@user.id}: #{e.message}")
      # Non-fatal — archive proceeds regardless. Support can clean up Stripe manually.
    end

    def rotate_jti
      @user.update_column(:jti, SecureRandom.uuid)
    end
  end
end
