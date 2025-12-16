# frozen_string_literal: true

json.data do
  # Summary statistics
  json.summary do
    json.total_balance(@total_balance)
    json.total_transactions(@total_transactions)
    json.total_statements(@total_statements)
    json.selected_month(@selected_month.strftime("%Y-%m"))
  end

  # Monthly summary
  json.monthly_summary do
    monthly_summary = @dashboard_data[:monthly_summary] || {}
    json.total_income(monthly_summary[:income] || 0)
    json.total_expenses(monthly_summary[:expenses] || 0)
    json.net_income(monthly_summary[:net] || 0)
    json.income_count(monthly_summary[:income_count] || 0)
    json.expense_count(monthly_summary[:expense_count] || 0)
  end

  # Monthly stats
  json.monthly_stats do
    monthly_stats = @dashboard_data[:monthly_stats] || {}
    json.average_transaction(monthly_stats[:average_transaction] || 0)
    json.largest_expense(monthly_stats[:largest_expense] || 0)
    json.largest_income(monthly_stats[:largest_income] || 0)
    json.daily_average(monthly_stats[:daily_average] || 0)
  end

  # Bank accounts
  json.bank_accounts(@dashboard_data[:bank_accounts] || []) do |account|
    json.id(account.id)
    json.name(account.display_name)
    json.custom_name(account.custom_name)
    json.bank_name(account.bank_display_name)
    json.account_type(account.account_type)
    json.opening_balance(account.opening_balance)
    json.balance(account.effective_balance)
    json.currency(account.currency)
  end

  # Bank summaries
  json.bank_summaries(@dashboard_data[:bank_summaries] || []) do |summary|
    json.account_id(summary[:account].id)
    json.account_name(summary[:account].display_name)
    json.bank_name(summary[:account].bank_display_name)
    json.balance(summary[:balance])
    json.transaction_count(summary[:transaction_count])
    json.recent_activity(summary[:recent_activity]&.iso8601)
    json.last_processed(summary[:last_processed]&.iso8601)
    json.status(summary[:status])
  end

  # Recent transactions
  json.recent_transactions(@dashboard_data[:recent_transactions] || []) do |transaction|
    json.partial!("api/v1/shared/transaction", transaction: transaction)
  end

  # Recent statement files
  json.recent_statement_files(@dashboard_data[:recent_statement_files] || []) do |statement_file|
    json.partial!("api/v1/shared/statement_file", statement_file: statement_file)
  end

  # Category summary
  json.category_summary do
    category_summary = @dashboard_data[:category_summary] || {}
    # categories is an array of [name, amount] pairs
    json.categories(category_summary[:categories] || []) do |category_name, amount|
      json.name(category_name)
      json.amount(amount)
    end
    json.has_data(category_summary[:has_data] || false)
  end

  # Spending trends
  json.spending_trends(@dashboard_data[:spending_trends] || []) do |trend|
    json.month(trend[:month])
    json.total_expenses(trend[:total_expenses])
    json.total_income(trend[:total_income])
    json.net_income(trend[:net_income])
  end

  # Available months for filtering
  json.available_months(@available_months || []) do |month|
    json.value(month.strftime("%Y-%m"))
    json.label(month.strftime("%B %Y"))
  end
end
