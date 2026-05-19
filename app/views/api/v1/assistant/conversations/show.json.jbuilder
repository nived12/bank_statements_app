json.data do
  json.conversation do
    json.partial! "api/v1/assistant/conversation", conversation: @conversation
  end

  json.messages @messages do |message|
    json.partial! "api/v1/assistant/message", message: message
  end
end

json.meta do
  json.usage @usage
end

json.message ""
