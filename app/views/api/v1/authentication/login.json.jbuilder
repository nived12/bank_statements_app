# frozen_string_literal: true

json.data do
  json.extract! @tokens, :access_token, :refresh_token, :expires_in, :token_type
  json.user do
    json.partial! "api/v1/authentication/user", user: @user
  end
end

json.message @message if @message.present?
