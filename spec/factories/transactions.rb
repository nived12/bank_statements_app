FactoryBot.define do
  factory :transaction do
    association :bank_account
    # Make the statement_file use the SAME bank_account
    statement_file { association :statement_file, bank_account: bank_account }

    date { Date.new(2025, 1, 5) }
    description { "Test transaction" }
    amount { -1299.99 }
    transaction_type { "variable_expense" }
    bank_entry_type { "debit" }
    merchant { "Test Merchant" }
    reference { "REF-123" }
    category { "Shopping" }
    sub_category { "Online" }

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
