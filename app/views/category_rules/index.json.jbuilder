json.category_rules @category_rules do |rule|
  json.id rule.id
  json.pattern rule.pattern
  json.match_type rule.match_type
  json.category_id rule.category_id
  json.category_name rule.category.name
  json.category_parent_name rule.category.parent&.name
  json.hits_count rule.hits_count
  json.active rule.active
  json.priority rule.priority
  json.created_at rule.created_at
end
