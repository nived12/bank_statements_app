# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    user
    plan { :free }
    status { :trialing }
    trial_ends_at { 30.days.from_now }
    current_period_end { 30.days.from_now }

    trait :active do
      status { :active }
      trial_ends_at { nil }
    end

    trait :pro do
      plan { :pro }
      status { :active }
    end

    trait :enterprise do
      plan { :enterprise }
      status { :active }
    end

    trait :past_due do
      status { :past_due }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :trial_expired do
      status { :trialing }
      trial_ends_at { 1.day.ago }
    end
  end
end
