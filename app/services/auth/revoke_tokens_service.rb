# frozen_string_literal: true

module Auth
  ##
  # Auth::RevokeTokensService
  # Revokes all JWT tokens for a user (logout)
  #
  # This works by changing the user's JTI, which invalidates all existing tokens
  # since the JTI in the token won't match the user's current JTI
  #
  # Usage:
  #   result = Auth::RevokeTokensService.call(user)
  #   if result.success?
  #     # User has been logged out, all tokens invalidated
  #   end
  #
  class RevokeTokensService < ApplicationService
    def initialize(user)
      super()
      @user = user
    end

    def call
      return failure("User is required") if @user.blank?

      # Generate a new JTI to invalidate all existing tokens
      new_jti = JsonWebToken.generate_jti

      # Clear refresh token expiration
      unless @user.update(
        jti: new_jti,
        refresh_token_expires_at: nil
      )
        errors.add(:base, "Failed to revoke tokens")
        @user.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        return failure
      end

      success({ message: "Tokens revoked successfully" })
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
