FactoryBot.define do
  factory :transaction do
    user
    bank_account
    statement_file
    category

    # Use fixed values instead of dynamic ones for speed
    date { Date.new(2025, 1, 5) }
    description { "Test transaction" }
    amount { -1299.99 }
    transaction_type { "variable_expense" }
    bank_entry_type { "debit" }
    merchant { "Test Merchant" }
    reference { "REF-123" }

    # Use build_stubbed for associations when not needed in database
    trait :stubbed do
      statement_file { build_stubbed(:statement_file) }
      category { build_stubbed(:category) }
    end

    trait :income do
      amount { 15000.0 }
      transaction_type { "income" }
      bank_entry_type { "credit" }
      description { "Salary" }
    end

    trait :fixed_expense do
      amount { -12000.0 }
      transaction_type { "fixed_expense" }
      bank_entry_type { "debit" }
      description { "Rent" }
    end

    trait :variable_expense do
      amount { -89.0 }
      transaction_type { "variable_expense" }
      bank_entry_type { "debit" }
      description { "Snacks" }
    end
  end
end
