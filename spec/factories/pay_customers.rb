# frozen_string_literal: true

FactoryBot.define do
  factory :pay_customer, class: "Pay::Customer" do
    association :owner, factory: :user
    processor { "stripe" }
    processor_id { "manual_#{owner.id}" }
  end
end
