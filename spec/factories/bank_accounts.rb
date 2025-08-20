FactoryBot.define do
  factory :bank_account do
    association :user
    association :bank
    account_number { Faker::Bank.account_number(digits: 10) }
    currency { "MXN" }
    opening_balance { Faker::Number.decimal(l_digits: 5, r_digits: 2) }
    opening_balance_date { Date.current }
    custom_name { nil }

    trait :with_custom_name do
      custom_name { "My Personal Account" }
    end
  end
end
