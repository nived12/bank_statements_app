# frozen_string_literal: true

json.extract!(rule, :id, :pattern, :category_id, :hits_count, :active, :created_at, :updated_at)
json.merchant_name(rule.pattern)

json.category do
  if rule.category
    json.extract!(rule.category, :id, :name, :icon, :color)
  else
    json.null!
  end
end
