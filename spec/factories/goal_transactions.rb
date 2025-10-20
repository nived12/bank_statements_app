FactoryBot.define do
  factory :goal_transaction do
    goal
    # Using 'txn' association name to avoid conflict with ActiveRecord's transaction method
    association :txn, factory: :transaction
    amount_applied { 100.0 }
    notes { nil }

    # Trait for partial amount
    trait :partial do
      amount_applied { 50.0 }
      notes { "Partial contribution to goal" }
    end

    # Trait for full transaction amount
    trait :full do
      # txn is the association name
      amount_applied { txn.amount.abs }
      notes { "Full transaction amount applied" }
    end
  end
end
