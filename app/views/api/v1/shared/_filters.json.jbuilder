# frozen_string_literal: true

filters = local_assigns[:filters] || {}

json.filters do
  json.bank_account_id(filters[:bank_account_id])
  json.statement_file_id(filters[:statement_file_id])
  json.transaction_type(filters[:transaction_type])
  json.from_date(filters[:from_date])
  json.to_date(filters[:to_date])
  json.search(filters[:search])

  if local_assigns.fetch(:include_sort, true)
    json.sort(filters[:sort])
    json.direction(filters[:direction])
  end
end
