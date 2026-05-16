# frozen_string_literal: true

FactoryBot.define do
  factory :pay_subscription, class: "Pay::Subscription" do
    association :customer, factory: :pay_customer
    name { "premium" }
    processor_id { "manual_sub_#{SecureRandom.hex(8)}" }
    processor_plan { "premium" }
    status { "active" }

    trait :past_due do
      status { "past_due" }
    end

    trait :canceled do
      status { "canceled" }
      ends_at { 1.day.ago }
    end
  end
end
