# frozen_string_literal: true

json.data do
  json.debts(@debts) do |debt|
    json.partial!("api/v1/shared/debt", debt: debt)
  end
end

# Pagination metadata
json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end
end
