FactoryBot.define do
  factory :recurring_series do
    user
    sequence(:name) { |n| "Series #{n}" }
    sequence(:description_signature) { |n| "signature-#{n}" }
    expected_amount { 219.00 }
    frequency { "monthly" }
    transaction_type { "fixed_expense" }
    status { "active" }
    source { "manual" }
    next_due_date { Date.current + 7.days }

    trait :detected do
      status { "detected" }
      source { "detected" }
      confidence_score { 85 }
      detected_at { Time.current }
    end

    trait :paused do
      status { "paused" }
    end

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { Time.current }
    end
  end
end
