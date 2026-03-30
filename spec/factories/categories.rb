FactoryBot.define do
  factory :category do
    user { nil }
    sequence(:name) { |n| "Category #{n}" }
    parent { nil }
  end
end
