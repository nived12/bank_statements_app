# frozen_string_literal: true

json.extract!(
  goal, :id, :name, :goal_type, :status, :color, :icon, :start_date, :deadline, :debt_strategy, :notes,
  :created_at, :updated_at
)

# Computed progress fields
json.progress_percentage(goal.progress_percentage.to_f)
json.amount_remaining(goal.amount_remaining.to_f)
json.days_remaining(goal.days_remaining)
json.monthly_contribution_needed(goal.monthly_contribution_needed.to_f)
json.on_track(goal.on_track?)

# Associated savings
json.savings(goal.savings) do |saving|
  json.id(saving.id)
  json.name(saving.name)
  json.progress_percentage(saving.progress_percentage.to_f)
  json.current_amount(saving.current_amount.to_f)
  json.target_amount(saving.target_amount.to_f)
  json.color(saving.color)
end

# Associated debts
json.debts(goal.debts) do |debt|
  json.id(debt.id)
  json.name(debt.name)
  json.progress_percentage(debt.progress_percentage.to_f)
  json.current_balance(debt.current_balance.to_f)
  json.original_amount(debt.original_amount.to_f)
  json.color(debt.color)
end
