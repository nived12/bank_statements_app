FactoryBot.define do
  factory :bank do
    sequence(:code) { |n| "test_bank_#{n}" }
    sequence(:name) { |n| "Test Bank #{n}" }
    supported_type { "both" }
    active { true }

    trait :bbva do
      code { "test_bbva" }
      name { "Test BBVA" }
    end

    trait :santander do
      code { "test_santander" }
      name { "Test Santander" }
    end

    trait :banorte do
      code { "test_banorte" }
      name { "Test Banorte" }
    end

    trait :banamex do
      code { "test_banamex" }
      name { "Test Banamex" }
    end

    trait :generic do
      code { "test_generic" }
      name { "Test Generic" }
      supported_type { nil }
    end

    trait :unsupported do
      supported_type { nil }
    end

    trait :debit_only do
      supported_type { "debit" }
    end

    trait :credit_only do
      supported_type { "credit" }
    end

    trait :inactive do
      active { false }
    end
  end
end
