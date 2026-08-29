json.id @saving.id
json.name @saving.name
json.target_amount @saving.target_amount
json.current_amount @saving.current_amount
json.target_date @saving.target_date
json.progress_percentage @saving.progress_percentage
json.status @saving.status
json.icon @saving.icon
json.color @saving.color
json.category_id @saving.category_id
json.bank_account_id @saving.bank_account_id
json.auto_link_category @saving.auto_link_category
json.calculation_settings @saving.calculation_settings
json.notes @saving.notes
# Contribution tracking fields
json.target_contribution_amount @saving.target_contribution_amount
json.contribution_frequency @saving.contribution_frequency
json.contribution_mode @saving.contribution_mode
json.calculated_period_contribution @saving.calculated_period_contribution
json.suggested_target_date @saving.suggested_target_date
json.current_month_progress @saving.current_month_progress
json.created_at @saving.created_at
json.updated_at @saving.updated_at

json.goals @saving.goals do |goal|
  json.id goal.id
  json.name goal.name
  json.goal_type goal.goal_type
  json.debt_strategy goal.debt_strategy
end

json.saving_transactions @saving_transactions do |saving_transaction|
  json.id saving_transaction.id
  json.amount_applied saving_transaction.amount_applied
  json.created_at saving_transaction.created_at

  json.transaction do
    json.id saving_transaction.transaction_record.id
    json.description saving_transaction.transaction_record.description
    json.amount saving_transaction.transaction_record.amount
    json.date saving_transaction.transaction_record.date
    json.category_id saving_transaction.transaction_record.category_id
  end
end
