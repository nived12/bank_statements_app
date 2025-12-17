# frozen_string_literal: true

json.data do
  # Transactions array
  json.transactions(@transactions) do |transaction|
    json.partial!("api/v1/shared/transaction", transaction: transaction)
  end
end

# Pagination metadata
json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end

  # Statistics
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

  # Active filters (always present with default values)
  filters = @filters || {}

  json.filters do
    json.bank_account_id(filters[:bank_account_id] || nil)
    json.statement_file_id(filters[:statement_file_id] || nil)
    json.transaction_type(filters[:transaction_type] || nil)
    json.from_date(filters[:from_date] || nil)
    json.to_date(filters[:to_date] || nil)
    json.search(filters[:search] || nil)
    json.sort(filters[:sort] || nil)
    json.direction(filters[:direction] || nil)
  end
end
