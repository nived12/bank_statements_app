# frozen_string_literal: true

FactoryBot.define do
  factory :assistant_conversation do
    association :user
    locale { "es-MX" }
    title { "Conversación de prueba" }
    disclaimer_shown { false }
  end
end
