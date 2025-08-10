# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { "Jane" }
    last_name  { "Doe" }
    sequence(:email) { |n| "jane#{n}@example.com" }
    password { "secret123" }
    password_confirmation { "secret123" }
  end
end
