# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    first_name { "Jane" }
    last_name  { "Doe" }
    sequence(:email) { |n| "jane#{n}@example.com" }
    password { "secret123" }
    password_confirmation { "secret123" }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :oauth do
      provider { "google_oauth2" }
      uid { SecureRandom.uuid }
      password { nil }
      password_confirmation { nil }
      confirmed_at { Time.current }
    end
  end
end
