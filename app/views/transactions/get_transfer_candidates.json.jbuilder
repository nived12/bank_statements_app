json.candidates @candidates do |candidate|
  json.id candidate.id
  json.similarity_score candidate.similarity_score&.to_f
  json.created_at candidate.created_at

  json.outgoing do
    txn = candidate.outgoing_transaction
    json.id txn.id
    json.date txn.date.strftime("%Y-%m-%d")
    json.description txn.description
    json.concept txn.concept
    json.amount txn.amount.to_f
    json.transaction_type txn.transaction_type
    json.bank_account do
      json.id txn.bank_account.id
      json.display_name txn.bank_account.display_name
    end
  end

  json.incoming do
    txn = candidate.incoming_transaction
    json.id txn.id
    json.date txn.date.strftime("%Y-%m-%d")
    json.description txn.description
    json.concept txn.concept
    json.amount txn.amount.to_f
    json.transaction_type txn.transaction_type
    json.bank_account do
      json.id txn.bank_account.id
      json.display_name txn.bank_account.display_name
    end
  end
end
