# frozen_string_literal: true

module Auth
  ##
  # Auth::RefreshTokensService
  # Refreshes JWT tokens using a valid refresh token
  #
  # Usage:
  #   result = Auth::RefreshTokensService.call(refresh_token)
  #   if result.success?
  #     tokens = result.payload
  #     tokens[:access_token]  # New JWT access token
  #     tokens[:refresh_token] # New JWT refresh token
  #   end
  #
  class RefreshTokensService < ApplicationService
    def initialize(refresh_token)
      super()
      @refresh_token = refresh_token
    end

    def call
      return failure("Refresh token is required") if @refresh_token.blank?

      # Decode the refresh token
      decoded_token = JsonWebToken.decode(@refresh_token)
      return failure("Invalid or expired refresh token") if decoded_token.blank?

      # Verify it's a refresh token
      return failure("Invalid token type") unless decoded_token[:type] == "refresh"

      # Find the user
      user = User.find_by(id: decoded_token[:user_id])
      return failure("User not found") if user.blank?

      # Verify the JTI matches (token hasn't been revoked)
      return failure("Token has been revoked") if user.jti != decoded_token[:jti]

      # Verify the refresh token hasn't expired
      unless user.refresh_token_expires_at.present? &&
             user.refresh_token_expires_at > Time.current
        return failure("Refresh token expired or invalid")
      end

      # Generate new tokens
      result = Auth::GenerateTokensService.call(user)

      if result.success?
        success(result.payload)
      else
        add_errors_from(result)
        failure
      end
    end

    private

    def context_for_logging
      decoded = JsonWebToken.decode(@refresh_token) rescue nil
      {
        user_id: decoded&.dig(:user_id),
        jti: decoded&.dig(:jti)
      }
    end
  end
end
