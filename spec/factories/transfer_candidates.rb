FactoryBot.define do
  factory :transfer_candidate do
    user
    association :outgoing_transaction, factory: :transaction
    association :incoming_transaction, factory: %i[transaction income]
    status { "pending" }
    similarity_score { 0.5 }
  end
end
