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
      terms_accepted_at { Time.current }
      privacy_accepted_at { Time.current }
      legal_version_accepted { LegalDocument::CURRENT_VERSION }
    end

    trait :consented do
      confirmed_at { Time.current }
      terms_accepted_at { Time.current }
      privacy_accepted_at { Time.current }
      legal_version_accepted { LegalDocument::CURRENT_VERSION }
    end

    trait :not_consented do
      legal_version_accepted { nil }
      terms_accepted_at { nil }
      privacy_accepted_at { nil }
    end

    trait :oauth do
      provider { "google_oauth2" }
      uid { SecureRandom.uuid }
      password { SecureRandom.hex(16) }
      password_confirmation { |u| u.password }
      confirmed_at { Time.current }
    end
  end
end
