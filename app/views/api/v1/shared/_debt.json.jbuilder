# frozen_string_literal: true

json.extract!(
  debt, :id, :name, :status, :color,
  :icon, :notes, :payment_mode, :payment_frequency, :target_payoff_date,
  :due_day_of_month, :auto_sync_transactions, :calculation_settings, :created_at, :updated_at
)

json.original_amount(debt.original_amount.to_f)
json.current_balance(debt.current_balance.to_f)
json.opening_balance(debt.opening_balance.to_f)
json.opening_balance_date(debt.opening_balance_date)
# Costs a MAX(transactions.date) query per record. Only the detail screen shows it,
# so the list payload does not pay for it.
json.balance_as_of(debt.balance_as_of) if local_assigns[:detailed]
json.interest_rate(debt.interest_rate.to_f)
json.minimum_payment(debt.minimum_payment.to_f)
json.target_payment_amount(debt.target_payment_amount.to_f)

# Progress information
json.progress_percentage(debt.progress_percentage.to_f)
json.amount_remaining(debt.current_balance.to_f)
json.amount_paid((debt.original_amount - debt.current_balance).to_f)

# Present only right after Debts::Creator/Updater ran a backfill or re-anchor unlink
if debt.backfill_summary.present?
  json.backfill_summary(debt.backfill_summary)
end

# Associated goals
json.goals(debt.goals) do |goal|
  json.extract!(goal, :id, :name, :color)
  json.strategy(goal.strategy) if goal.respond_to?(:strategy)
end

# Associated categories
json.categories(debt.categories) do |category|
  json.extract!(category, :id, :name, :icon)
end

# Associated bank accounts
json.bank_accounts(debt.bank_accounts) do |bank_account|
  json.extract!(bank_account, :id, :display_name, :currency)
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
if debt.goals.any? && debt.goals.first.present?
  json.priority_order(debt.priority_order(debt.goals.first))
end

# Payment information
if debt.interest_rate.present?
  json.has_interest_rate(true)
  # Next payment due date (from DebtPaymentSchedule concern)
  json.next_due_date(debt.calculate_next_due_date) if debt.due_day_of_month.present?
  json.payment_due_in_days(debt.payment_due_in_days) if debt.due_day_of_month.present?
  json.payment_overdue(debt.payment_overdue?)
end
