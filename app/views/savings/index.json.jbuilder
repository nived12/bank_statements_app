json.array! @savings do |saving|
  json.id saving.id
  json.name saving.name
  json.target_amount saving.target_amount
  json.current_amount saving.current_amount
  json.target_date saving.target_date
  json.progress_percentage saving.progress_percentage
  json.status saving.status
  json.icon saving.icon
  json.color saving.color
  json.category_id saving.category_id
  json.bank_account_id saving.bank_account_id
  json.auto_link_category saving.auto_link_category
  json.calculation_settings saving.calculation_settings
  json.notes saving.notes
  # Contribution tracking fields
  json.target_contribution_amount saving.target_contribution_amount
  json.contribution_frequency saving.contribution_frequency
  json.contribution_mode saving.contribution_mode
  json.suggested_target_date saving.suggested_target_date
  json.created_at saving.created_at
  json.updated_at saving.updated_at
  json.goals saving.goals do |goal|
    json.id goal.id
    json.name goal.name
    json.goal_type goal.goal_type
  end
end
