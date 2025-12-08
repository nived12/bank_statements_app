# frozen_string_literal: true

module Auth
  ##
  # Auth::GenerateTokensService
  # Generates JWT access and refresh tokens for a user
  #
  # Usage:
  #   result = Auth::GenerateTokensService.call(user)
  #   if result.success?
  #     tokens = result.payload
  #     tokens[:access_token]  # JWT access token (15 minutes)
  #     tokens[:refresh_token] # JWT refresh token (7 days)
  #   end
  #
  class GenerateTokensService < ApplicationService
    def initialize(user)
      super()
      @user = user
    end

    def call
      return failure("User is required") if @user.blank?
      return failure("User must be persisted") unless @user.persisted?

      # Generate new JTI (JWT ID) for this token set
      jti = JsonWebToken.generate_jti

      # Update user's JTI and refresh token expiration
      # Note: We don't store the JWT refresh token itself, just track expiration
      unless @user.update(
        jti: jti,
        refresh_token_expires_at: JsonWebToken::REFRESH_TOKEN_EXPIRATION.from_now
      )
        errors.add(:base, "Failed to update user tokens")
        @user.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        return failure
      end

      # Generate tokens using the new JTI
      access_token = JsonWebToken.generate_access_token(@user)
      refresh_token = JsonWebToken.generate_refresh_token(@user)

      success({
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: JsonWebToken::ACCESS_TOKEN_EXPIRATION.to_i,
        token_type: "Bearer"
      })
    end

    private

    def context_for_logging
      {
        user_id: @user&.id,
        user_email: @user&.email
      }
    end
  end
end
