# frozen_string_literal: true

json.extract!(saving, :id, :name, :target_amount, :current_amount, :target_date, :status, :color, :icon, :notes,
              :contribution_mode, :contribution_frequency, :target_contribution_amount, :auto_sync_transactions,
              :calculation_settings, :created_at, :updated_at)

# Progress information
json.progress_percentage(saving.progress_percentage)
json.amount_remaining(saving.amount_remaining)

# Associated goals
json.goals(saving.goals) do |goal|
  json.extract!(goal, :id, :name, :color)
end

# Associated categories
json.categories(saving.categories) do |category|
  json.extract!(category, :id, :name, :icon)
end

# Associated bank accounts
json.bank_accounts(saving.bank_accounts) do |bank_account|
  json.extract!(bank_account, :id, :display_name, :currency)
end

# Monthly timeline data (from Periodable concern)
json.monthly_timeline(saving.monthly_timeline) do |month_data|
  json.month(month_data[:month])
  json.month_short(month_data[:month_short])
  json.achieved(month_data[:achieved])
  json.target(month_data[:target])
  json.percentage(month_data[:percentage])
  json.start_date(month_data[:start_date])
  json.end_date(month_data[:end_date])
end

# Additional calculated fields based on contribution mode
if saving.contribution_mode == "calculated"
  json.calculated_monthly_contribution(saving.calculated_monthly_contribution || 0)
  json.behind_this_month(saving.behind_this_month?)
elsif saving.contribution_mode == "fixed"
  json.suggested_target_date(saving.suggested_target_date)
end
