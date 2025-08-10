FactoryBot.define do
  factory :category do
    user { nil }
    name { "MyString" }
    parent { nil }
  end
end
