FactoryBot.define do
  factory :category_rule do
    user
    category
    match_type { "contains" }
    pattern { "test pattern" }
    priority { 0 }
    hits_count { 0 }
    active { true }

    trait :exact do
      match_type { "exact" }
    end

    trait :starts_with do
      match_type { "starts_with" }
    end

    trait :inactive do
      active { false }
    end
  end
end
