# frozen_string_literal: true

stats = local_assigns[:stats] || {}

json.stats do
  json.total_transactions(stats[:total_transactions] || 0)
  json.income_total(stats[:income_total] || 0)
  json.expenses_total(stats[:expenses_total] || 0)
  json.equity_total(stats[:equity_total] || 0)
  json.income_count(stats[:income_count] || 0)
  json.fixed_expense_count(stats[:fixed_expense_count] || 0)
  json.variable_expense_count(stats[:variable_expense_count] || 0)
  json.category_count(stats[:category_count] || 0)
end
