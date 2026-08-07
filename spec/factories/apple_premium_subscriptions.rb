# frozen_string_literal: true

FactoryBot.define do
  factory :apple_premium_subscription do
    user
    expires_at { 1.month.from_now }
    billing_interval { "month" }
    billing_amount_cents { 9900 }
    billing_currency { "MXN" }
    original_transaction_id { "1000000#{SecureRandom.random_number(1_000_000)}" }

    trait :annual do
      billing_interval { "year" }
      billing_amount_cents { 89_900 }
      expires_at { 1.year.from_now }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end
  end
end
