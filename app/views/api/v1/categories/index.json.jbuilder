# frozen_string_literal: true

json.data do
  # Categories array (parent categories with their children)
  json.categories(@categories) do |category|
    json.partial!("api/v1/shared/category", category: category)
  end
end
