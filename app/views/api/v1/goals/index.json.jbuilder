# frozen_string_literal: true

json.data do
  json.goals(@goals) do |goal|
    json.partial!("api/v1/shared/goal", goal: goal)
  end
end

# Pagination metadata
json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end
end
