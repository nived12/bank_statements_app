# frozen_string_literal: true

json.data do
  json.message(@message)
  json.confirmed(@confirmed)

  # Tokens are only provided when confirming for the first time (not when already confirmed)
  if @tokens.present?
    json.extract!(@tokens, :access_token, :refresh_token, :expires_in)
    json.token_type("Bearer")
    json.user do
      json.partial!("api/v1/authentication/user", user: @user)
    end
  end
end
