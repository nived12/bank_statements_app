json.data do
  json.conversation do
    json.partial! "api/v1/assistant/conversation", conversation: @result.conversation
  end

  json.user_message do
    json.partial! "api/v1/assistant/message", message: @result.user_message
  end

  json.assistant_message do
    json.partial! "api/v1/assistant/message", message: @result.assistant_message
  end

  json.disclaimer @result.disclaimer
end

json.meta do
  json.usage @result.usage
end

json.message ""
