# frozen_string_literal: true

json.extract!(category, :id, :name, :icon, :parent_id, :created_at, :updated_at)

# Include transactions count (use .size to leverage preloaded association)
json.transactions_count(category.transactions.size)

# Include children (subcategories) with their data
json.children(category.children.order(:name)) do |child|
  json.extract!(child, :id, :name, :icon, :parent_id, :created_at, :updated_at)
  json.transactions_count(child.transactions.size)
end
