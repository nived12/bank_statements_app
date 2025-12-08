# frozen_string_literal: true

json.data do
  json.extract! @tokens, :access_token, :refresh_token, :expires_in, :token_type
end

json.message @message if defined?(@message) && @message.present?
