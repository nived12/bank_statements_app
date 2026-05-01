# frozen_string_literal: true

FactoryBot.define do
  factory :user_setting do
    user
    preferences { {} }

    trait :with_text_ai_default do
      preferences { { "processing_strategy" => "text_with_ai" } }
    end

    trait :with_vision_ai_default do
      preferences { { "processing_strategy" => "vision_ai" } }
    end
  end
end
