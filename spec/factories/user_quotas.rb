# frozen_string_literal: true

FactoryBot.define do
  factory :user_quota do
    user
    ai_usage_count { 0 }
    ai_usage_threshold_shown { 0 }
  end
end
