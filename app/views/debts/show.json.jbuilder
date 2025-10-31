json.id @debt.id
json.name @debt.name
json.original_amount @debt.original_amount
json.current_amount @debt.current_balance
json.interest_rate @debt.interest_rate
json.minimum_payment @debt.minimum_payment
json.progress_percentage @debt.progress_percentage
json.status @debt.status
json.icon @debt.icon
json.color @debt.color
json.category_id @debt.category_id
json.bank_account_id @debt.bank_account_id
json.auto_link_category @debt.auto_link_category
json.calculation_settings @debt.calculation_settings
json.notes @debt.notes
json.created_at @debt.created_at
json.updated_at @debt.updated_at

json.goals @debt.goals do |goal|
  json.id goal.id
  json.name goal.name
  json.goal_type goal.goal_type
  json.debt_strategy goal.debt_strategy
end

json.debt_transactions @debt_transactions do |debt_transaction|
  json.id debt_transaction.id
  json.amount_applied debt_transaction.amount_applied
  json.created_at debt_transaction.created_at

  json.transaction do
    json.id debt_transaction.transaction_record.id
    json.description debt_transaction.transaction_record.description
    json.amount debt_transaction.transaction_record.amount
    json.date debt_transaction.transaction_record.date
    json.category_id debt_transaction.transaction_record.category_id
  end
end
