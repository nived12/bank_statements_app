# Reusable pagination partial for JBuilder
# Usage: json.pagination { json.partial! "shared/pagination", pagy: @pagy }
# Or inline: json.pagination do
#              json.partial! "shared/pagination", pagy: @pagy
#            end

if pagy && pagy.respond_to?(:page)
  json.page pagy.page
  json.items pagy.items
  json.count pagy.count
  json.pages pagy.pages
  json.next pagy.next
  json.prev pagy.prev
else
  json.page 1
  json.items 0
  json.count 0
  json.pages 0
  json.next nil
  json.prev nil
end
