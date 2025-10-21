FactoryBot.define do
  factory :goal do
    user
    category { nil }  # Optional association

    # Use fixed values for speed
    name { "Test Goal" }
    goal_type { "savings_goal" }
    target_amount { 5000.0 }
    current_amount { 0.0 }
    start_date { Date.new(2025, 1, 1) }
    deadline { Date.new(2025, 12, 31) }
    auto_link_category { false }
    icon { "💰" }
    color { "#3B82F6" }
    status { "active" }
    notes { nil }

    # Traits for different goal types
    trait :savings_goal do
      name { "Vacation Fund" }
      goal_type { "savings_goal" }
      target_amount { 5000.0 }
      current_amount { 2000.0 }
      debt_strategy { nil }
      starting_debt_amount { nil }
      icon { "🏖️" }
    end

    trait :debt_payoff do
      name { "Pay Off Credit Card" }
      goal_type { "debt_payoff" }
      target_amount { 0.0 }
      starting_debt_amount { 10000.0 }
      current_amount { 6000.0 }
      debt_strategy { "avalanche" }
      icon { "💳" }
    end

    # Traits for different statuses
    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
      current_amount { target_amount }
    end

    trait :paused do
      status { "paused" }
    end

    trait :archived do
      status { "archived" }
    end

    # Traits for debt strategies
    trait :snowball do
      debt_strategy { "snowball" }
    end

    trait :avalanche do
      debt_strategy { "avalanche" }
    end

    # Trait with interest rate
    trait :with_interest_rate do
      interest_rate { 8.5 }
    end

    # Trait with auto-link enabled
    trait :with_auto_link do
      category
      auto_link_category { true }
    end

    # Trait for goal with linked transactions
    trait :with_transactions do
      transient do
        transactions_count { 3 }
        amount_per_transaction { 500.0 }
      end

      after(:create) do |goal, evaluator|
        evaluator.transactions_count.times do
          transaction = create(:transaction, user: goal.user)
          create(:goal_transaction,
                 goal: goal,
                 txn: transaction,
                 amount_applied: evaluator.amount_per_transaction)
        end
        goal.recalculate_current_amount!
      end
    end
  end
end
