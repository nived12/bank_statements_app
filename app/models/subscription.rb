class Subscription < ApplicationRecord
  belongs_to :user

  enum :plan, { free: "free", pro: "pro", enterprise: "enterprise" }, default: :free
  enum :status, { trialing: "trialing", active: "active", past_due: "past_due", cancelled: "cancelled" }, default: :trialing

  validates :user_id, uniqueness: true
end
