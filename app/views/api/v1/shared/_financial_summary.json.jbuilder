# frozen_string_literal: true

# Mirrors the web statement detail's "Resumen Financiero". Credit-only figures
# are emitted for credit statements only — the model returns nil otherwise.
json.statement_type(summary.statement_type)
json.statement_period_start(summary.statement_period_start&.iso8601)
json.statement_period_end(summary.statement_period_end&.iso8601)
json.days_in_period(summary.days_in_period)

json.initial_balance(summary.initial_balance)
json.final_balance(summary.final_balance)
json.net_movement(summary.net_movement)

json.total_deposits(summary.total_deposits)
json.total_withdrawals(summary.total_withdrawals)
json.interest_earned(summary.interest_earned)
json.total_commissions(summary.total_commissions)
json.total_fees(summary.total_fees)

if summary.statement_type_credit?
  json.total_payments(summary.total_payments)
  json.total_charges(summary.total_charges)
  json.credit_limit(summary.credit_limit)
  json.available_credit(summary.available_credit)
  json.minimum_payment(summary.minimum_payment)
end
