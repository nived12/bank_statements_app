# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/stats", stats: @stats)
end

# Metadata (always present with default values)
json.meta do
  # Active filters (always present as object with default values)
  json.partial!("api/v1/shared/filters", filters: @filters, include_sort: false)
end
