# frozen_string_literal: true

json.data do
  json.message @message
  json.confirmed @confirmed

  if @tokens.present?
    json.access_token @tokens[:access_token]
    json.refresh_token @tokens[:refresh_token]
    json.expires_in @tokens[:expires_in]
    json.token_type "Bearer"

    json.user do
      json.partial! "api/v1/authentication/user", user: @user
    end
  end
end
