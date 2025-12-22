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

  # Active filters (always present with default values)
  json.partial!("api/v1/shared/filters", filters: @filters, include_sort: true)
end
