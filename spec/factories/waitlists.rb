FactoryBot.define do
  factory :waitlist do
    sequence(:email) { |n| "user#{n}@example.com" }
    locale { "es" }
  end
end
