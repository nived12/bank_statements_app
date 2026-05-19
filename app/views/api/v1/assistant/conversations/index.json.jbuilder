json.data do
  json.conversations @conversations do |conversation|
    json.partial! "api/v1/assistant/conversation", conversation: conversation
  end
end

json.meta do
  json.pagination do
    json.page @pagy.page
    json.pages @pagy.pages
    json.count @pagy.count
    json.page_size @pagy.limit
  end
end

json.message ""
