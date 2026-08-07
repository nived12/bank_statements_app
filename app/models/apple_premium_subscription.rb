# frozen_string_literal: true

# Current App Store entitlement for a user, upserted by the RevenueCat webhook.
# Apple owns the real subscription; this is only the answer to "is it live, and
# what are they paying?" — see Api::V1::RevenuecatWebhooksController.
class ApplePremiumSubscription < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true
  validates :expires_at, presence: true

  def active?
    expires_at.present? && expires_at > Time.current
  end

  # Symbol, to match PaySubscriptionInterval — User#billing_interval delegates to
  # whichever source is live and callers must not have to care which one answered.
  def billing_interval
    self[:billing_interval]&.to_sym
  end

  def annual?
    billing_interval == :year
  end
end
