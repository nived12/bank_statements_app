FactoryBot.define do
  factory :pending_transaction do
    association :statement_file
    association :user
    association :bank_account
    date { Date.current }
    description { "Test Transaction" }
    amount { 100.00 }
    transaction_type { "variable_expense" }
    merchant { "Test Merchant" }
    reference { "REF123456" }
    category_id { nil }
    confidence { 0.95 }
    category_confidence { 0.90 }
    transaction_type_confidence { 0.85 }
    source { :statement_file }

    trait :manual do
      source { :manual }
    end

    trait :statement_file_source do
      source { :statement_file }
    end

    trait :income do
      transaction_type { "income" }
      amount { 500.00 }
    end

    trait :expense do
      transaction_type { "variable_expense" }
      amount { -100.00 }
    end
  end
end
