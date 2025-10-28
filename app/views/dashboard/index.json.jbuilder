json.dashboard do
  json.selected_month @selected_month.strftime("%Y-%m")
  json.available_months @available_months.map { |m| m.strftime("%Y-%m") }
  json.widgets @widgets.map { |w| { id: w["id"], enabled: w["enabled"], position: w["position"], size: w["size"] } }

  json.data do
    json.total_balance @total_balance
    json.total_transactions @total_transactions
    json.total_statements @total_statements

    json.bank_accounts do
      json.array! @bank_accounts do |account|
        json.id account.id
        json.bank_name account.bank_display_name
        json.custom_name account.custom_name
        json.account_number account.account_number
      end
    end

    json.monthly_summary do
      json.income @monthly_summary[:income]
      json.expenses @monthly_summary[:expenses]
      json.net @monthly_summary[:net]
      json.count @monthly_summary[:count]
      json.has_data @monthly_summary[:has_data]
      json.income_count @monthly_summary[:income_count]
      json.expense_count @monthly_summary[:expense_count]
    end

    json.recent_transactions do
      json.array! @recent_transactions do |transaction|
        json.id transaction.id
        json.description transaction.description
        json.amount transaction.amount
        json.date transaction.date
        json.category transaction.category&.name
        json.account transaction.bank_account.custom_name
      end
    end
  end

  json.error @error if @error
end
