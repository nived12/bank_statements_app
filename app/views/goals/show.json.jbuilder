json.id @goal.id
json.name @goal.name
json.goal_type @goal.goal_type
json.target_amount @goal.target_amount
json.current_amount @goal.current_amount
json.progress_percentage @goal.progress_percentage
json.status @goal.status
json.start_date @goal.start_date
json.deadline @goal.deadline
json.debt_strategy @goal.debt_strategy
json.notes @goal.notes
json.icon @goal.icon
json.color @goal.color
json.created_at @goal.created_at
json.updated_at @goal.updated_at

# Monthly timeline data
json.monthly_timeline @goal.monthly_timeline(12)

# Recommended debt (for debt payoff goals with strategy)
if @goal.type_debt_payoff? && @goal.debt_strategy.present?
  recommendation = @goal.recommended_debt
  if recommendation.present?
    json.recommended_debt do
      json.debt do
        json.id recommendation[:debt].id
        json.name recommendation[:debt].name
        json.current_balance recommendation[:debt].current_balance
        json.interest_rate recommendation[:debt].interest_rate
      end
      json.reason recommendation[:reason]
      json.strategy recommendation[:strategy]
    end
  end
end

# Associated debts (for debt payoff goals)
if @goal.type_debt_payoff?
  json.debts @debts do |debt|
    json.id debt.id
    json.name debt.name
    json.current_balance debt.current_balance
    json.original_amount debt.original_amount
    json.interest_rate debt.interest_rate
    json.progress_percentage debt.progress_percentage
  end
end

# Associated savings (for savings goals)
if @goal.type_savings_goal?
  json.savings @savings do |saving|
    json.id saving.id
    json.name saving.name
    json.current_amount saving.current_amount
    json.target_amount saving.target_amount
    json.progress_percentage saving.progress_percentage
  end
end
