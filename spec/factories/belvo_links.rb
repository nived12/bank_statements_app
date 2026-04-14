FactoryBot.define do
  factory :belvo_link do
    association :user
    association :bank
    belvo_link_id { SecureRandom.uuid }
    belvo_institution { "bbva_mx_retail" }
    status { "active" }
    access_mode { "recurrent" }
    sync_status { "pending" }

    trait :synced do
      sync_status { "synced" }
      last_synced_at { Time.current }
    end

    trait :needs_reauth do
      status { "token_required" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :with_error do
      sync_status { "error" }
      sync_error_message { "Connection timeout" }
    end
  end
end
