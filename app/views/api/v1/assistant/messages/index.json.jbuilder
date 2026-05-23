json.data do
  json.messages @messages do |message|
    json.partial! "api/v1/assistant/message", message: message
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
