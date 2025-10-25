FactoryBot.define do
  factory :debt do
    user
    name { "Test Debt" }
    original_amount { 10000.0 }
    current_balance { 10000.0 }
    interest_rate { 18.5 }
    minimum_payment { 150.0 }
    icon { "💳" }
    color { "#EF4444" }
    status { "active" }
    notes { nil }
    auto_sync_transactions { false }

    # Traits for different statuses
    trait :active do
      status { "active" }
    end

    trait :paid_off do
      status { "paid_off" }
      current_balance { 0.0 }
    end

    trait :paused do
      status { "paused" }
    end

    trait :archived do
      status { "archived" }
    end

    # Trait with auto sync enabled
    trait :with_auto_sync do
      auto_sync_transactions { true }
    end

    # Trait with high interest rate
    trait :high_interest do
      interest_rate { 25.0 }
    end

    # Trait with low interest rate
    trait :low_interest do
      interest_rate { 5.0 }
    end
  end
end
