# frozen_string_literal: true

FactoryBot.define do
  factory :pay_subscription, class: "Pay::Subscription" do
    association :customer, factory: :pay_customer
    name { "premium" }
    processor_id { "manual_sub_#{SecureRandom.hex(8)}" }
    processor_plan { "premium" }
    status { "active" }

    # The default above is a manually granted comp account: bare plan name, no Stripe
    # price, no synced object. The traits below mirror real Stripe-synced rows, where
    # Pay stores the API object in `object` and tracks the billing period.
    trait :stripe_annual do
      processor_id { "sub_#{SecureRandom.hex(8)}" }
      processor_plan { "price_annual_#{SecureRandom.hex(4)}" }
      current_period_start { Time.current }
      current_period_end { 1.year.from_now }
      object { { "items" => { "data" => [ { "price" => { "recurring" => { "interval" => "year" } } } ] } } }
    end

    trait :stripe_monthly do
      processor_id { "sub_#{SecureRandom.hex(8)}" }
      processor_plan { "price_monthly_#{SecureRandom.hex(4)}" }
      current_period_start { Time.current }
      current_period_end { 1.month.from_now }
      object { { "items" => { "data" => [ { "price" => { "recurring" => { "interval" => "month" } } } ] } } }
    end

    trait :past_due do
      status { "past_due" }
    end

    trait :canceled do
      status { "canceled" }
      ends_at { 1.day.ago }
    end
  end
end
