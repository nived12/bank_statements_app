class Subscription < ApplicationRecord
  belongs_to :user

  enum :plan, { free: "free", pro: "pro", enterprise: "enterprise" }, default: :free
  enum :status, { trialing: "trialing", active: "active", past_due: "past_due", cancelled: "cancelled" },
    default: :trialing

  validates :user_id, uniqueness: true
end

# == Schema Information
#
# Table name: subscriptions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_subscriptions_on_user_id
#  plan                 :string          not null   default: free        index: index_subscriptions_on_plan
#  status               :string          not null   default: trialing    index: index_subscriptions_on_status
#  trial_ends_at        :datetime        null       no default           no index
#  current_period_end   :datetime        null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_subscriptions_on_plan    (plan) non-unique
#  index_subscriptions_on_status  (status) non-unique
#  index_subscriptions_on_user_id (user_id) unique
#
