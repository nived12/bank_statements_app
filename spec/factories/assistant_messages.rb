# frozen_string_literal: true

FactoryBot.define do
  factory :assistant_message do
    association :assistant_conversation
    association :user
    role { "user" }
    content { "Mensaje de prueba" }
    is_deterministic { false }
    prompt_tokens { 0 }
    completion_tokens { 0 }
    cost_usd { 0.0 }
  end
end
