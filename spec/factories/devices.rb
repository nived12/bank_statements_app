# frozen_string_literal: true

FactoryBot.define do
  factory :device do
    association :user
    push_token { "ExponentPushToken[#{SecureRandom.hex(10)}]" }
    platform { "ios" }
    active { true }
  end
end
