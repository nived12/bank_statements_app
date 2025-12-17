# frozen_string_literal: true

json.data do
  if @stats.present?
    json.stats do
      json.total_transactions(@stats[:total_transactions])
      json.income_total(@stats[:income_total])
      json.expenses_total(@stats[:expenses_total])
      json.equity_total(@stats[:equity_total])
      json.income_count(@stats[:income_count])
      json.fixed_expense_count(@stats[:fixed_expense_count])
      json.variable_expense_count(@stats[:variable_expense_count])
      json.category_count(@stats[:category_count])
    end
  end
end

# Metadata (always present with default values)
json.meta do
  # Active filters (always present as object with default values)
  filters = @filters || {}

  json.filters do
    json.bank_account_id(filters[:bank_account_id] || nil)
    json.statement_file_id(filters[:statement_file_id] || nil)
    json.transaction_type(filters[:transaction_type] || nil)
    json.from_date(filters[:from_date] || nil)
    json.to_date(filters[:to_date] || nil)
    json.search(filters[:search] || nil)
  end
end
