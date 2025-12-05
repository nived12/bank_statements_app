FactoryBot.define do
  factory :goal do
    user

    # Use sequences to avoid test conflicts
    name { "Test Goal" }
    goal_type { "savings_goal" }
    sequence(:start_date) { |n| Date.current + n.days }
    sequence(:deadline) { |n| Date.current + (n + 30).days }
    icon { "💰" }
    color { "#3B82F6" }
    status { "active" }
    notes { nil }

    # Traits for different goal types
    trait :savings_goal do
      name { "Vacation Fund" }
      goal_type { "savings_goal" }
      debt_strategy { nil }
      icon { "🏖️" }
    end

    trait :debt_payoff do
      name { "Pay Off Credit Card" }
      goal_type { "debt_payoff" }
      debt_strategy { "avalanche" }
      icon { "💳" }
    end

    # Traits for different statuses
    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
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

    # Trait for goal with linked savings
    trait :with_savings do
      transient do
        savings_count { 3 }
        amount_per_saving { 500.0 }
      end

      after(:create) do |goal, evaluator|
        evaluator.savings_count.times do
          saving = create(:saving, user: goal.user, target_amount: evaluator.amount_per_saving)
          goal.goal_savings.create!(saving: saving)
        end
        goal.recalculate_current_amount!
      end
    end
  end
end
