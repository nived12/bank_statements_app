# frozen_string_literal: true

json.extract!(debt, :id, :name, :original_amount, :current_balance, :interest_rate, :minimum_payment, :status, :color, :icon, :notes, :created_at, :updated_at)

# Progress information
json.progress_percentage(debt.progress_percentage)
json.amount_remaining(debt.current_balance)
json.amount_paid(debt.original_amount - debt.current_balance)

# Payment tracking
json.payment_mode(debt.payment_mode)
json.payment_frequency(debt.payment_frequency)
json.target_payment_amount(debt.target_payment_amount || 0)
json.target_payoff_date(debt.target_payoff_date)
json.due_day_of_month(debt.due_day_of_month)

# Auto-sync settings
json.auto_sync_transactions(debt.auto_sync_transactions)
json.calculation_settings(debt.calculation_settings || {})

# Associated goals
json.goals(debt.goals) do |goal|
  json.id(goal.id)
  json.name(goal.name)
  json.color(goal.color)
  json.strategy(goal.strategy) if goal.respond_to?(:strategy)
end

# Associated categories
json.categories(debt.categories) do |category|
  json.id(category.id)
  json.name(category.name)
  json.icon(category.icon)
end

# Associated bank accounts
json.bank_accounts(debt.bank_accounts) do |bank_account|
  json.id(bank_account.id)
  json.display_name(bank_account.display_name)
  json.currency(bank_account.currency)
end

# Monthly timeline data (from Periodable concern)
json.monthly_timeline(debt.monthly_timeline) do |month_data|
  json.month(month_data[:month])
  json.month_short(month_data[:month_short])
  json.achieved(month_data[:achieved])
  json.target(month_data[:target])
  json.percentage(month_data[:percentage])
  json.start_date(month_data[:start_date])
  json.end_date(month_data[:end_date])
end

# Priority for debt payoff strategies
if debt.goals.any?
  json.priority_order(debt.priority_order(debt.goals.first))
end

# Payment schedule (if available from controller)
if defined?(@payment_schedule) && @payment_schedule.present?
  json.payment_schedule(@payment_schedule) do |payment|
    json.extract!(payment, :payment_number, :payment_date, :payment_amount, :principal, :interest, :remaining_balance)
  end
elsif debt.interest_rate.present? && debt.target_payment_amount.present?
  # Fallback for index view - just indicate schedule is available
  json.has_payment_schedule(true)
end
