# frozen_string_literal: true

json.extract!(category, :id, :name, :icon, :color, :parent_id, :created_at, :updated_at)

json.transactions_count(category.transactions.size)

json.children(category.children.order(:name)) do |child|
  json.extract!(child, :id, :name, :icon, :color, :parent_id, :created_at, :updated_at)
  json.transactions_count(child.transactions.size)
end
