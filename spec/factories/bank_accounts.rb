FactoryBot.define do
  factory :bank_account do
    association :user
    association :bank
    account_number { Faker::Bank.account_number(digits: 10) }
    currency { "MXN" }
    opening_balance { Faker::Number.decimal(l_digits: 5, r_digits: 2) }
    opening_balance_date { Date.current }
    custom_name { nil }

    trait :bbva do
      after(:build) do |bank_account|
        # Use build_stubbed to avoid database queries
        bank_account.bank = build_stubbed(:bank, code: "bbva", name: "BBVA Bancomer")
      end
    end

    trait :santander do
      after(:build) do |bank_account|
        bank_account.bank = build_stubbed(:bank, code: "santander", name: "Santander")
      end
    end

    trait :banorte do
      after(:build) do |bank_account|
        bank_account.bank = build_stubbed(:bank, code: "banorte", name: "Banorte")
      end
    end

    trait :banamex do
      after(:build) do |bank_account|
        bank_account.bank = build_stubbed(:bank, code: "banamex", name: "Banamex")
      end
    end

    trait :generic do
      after(:build) do |bank_account|
        bank_account.bank = build_stubbed(:bank, code: "generic", name: "Otro Banco", supported: false)
      end
    end

    trait :with_custom_name do
      custom_name { "My Personal Account" }
    end
  end
end
