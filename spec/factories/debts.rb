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
    # Simulates real UI flow: create debt -> add associations -> enable auto_sync
    trait :with_auto_sync do
      auto_sync_transactions { false }

      after(:create) do |debt|
        # Add required associations
        debt.categories << create(:category, user: debt.user)
        debt.bank_accounts << create(:bank_account, user: debt.user)
        # Now enable auto_sync (validation will pass because associations exist)
        debt.update!(auto_sync_transactions: true)
      end
    end

    # Trait with high interest rate
    trait :high_interest do
      interest_rate { 25.0 }
    end

    # Trait with low interest rate
    trait :low_interest do
      interest_rate { 5.0 }
    end

    # Trait with fixed payment mode
    trait :with_fixed_payment do
      payment_mode { "fixed" }
      payment_frequency { "monthly" }
      target_payment_amount { 500.0 }
    end

    # Trait with calculated payment mode
    trait :with_calculated_payment do
      payment_mode { "calculated" }
      payment_frequency { "monthly" }
      target_payoff_date { 1.year.from_now }
    end

    # Trait with target payoff date
    trait :with_target_date do
      target_payoff_date { 2.years.from_now }
    end
  end
end
