FactoryBot.define do
  factory :saving do
    user
    name { "Test Saving" }
    target_amount { 5000.0 }
    icon { "💰" }
    color { "#3B82F6" }
    status { "active" }
    notes { nil }
    auto_sync_transactions { false }

    # Traits for different statuses
    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
      opening_balance { target_amount }
    end

    trait :paused do
      status { "paused" }
    end

    trait :archived do
      status { "archived" }
    end

    # Trait with auto sync enabled
    trait :with_auto_sync do
      after(:create) do |saving|
        saving.categories << create(:category, user: saving.user)
        saving.bank_accounts << create(:bank_account, user: saving.user)
        saving.update!(auto_sync_transactions: true)
      end
    end
  end
end
