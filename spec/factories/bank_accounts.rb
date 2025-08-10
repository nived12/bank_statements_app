FactoryBot.define do
  factory :bank_account do
    association :user
    bank_name { Faker::Bank.name }
    account_number { Faker::Bank.account_number(digits: 10) }
    currency { "MXN" }
    opening_balance { Faker::Number.decimal(l_digits: 5, r_digits: 2) }
  end
end
