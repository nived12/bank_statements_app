# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::EmailConfirmationsController
    # Handles email confirmation for API clients
    #
    # Endpoints:
    # - POST /api/v1/email_confirmations - Resend confirmation email
    # - PATCH /api/v1/email_confirmations/:token - Confirm email with token
    #
    class EmailConfirmationsController < BaseController
      skip_before_action :authenticate_api_user!

      # POST /api/v1/email_confirmations
      # Resend confirmation email.
      # Works in two modes:
      #   1. Authenticated: uses the JWT bearer token to find the current user (mobile)
      #   2. Unauthenticated: looks up user by ?email param (web / pre-login flows)
      def create
        user = authenticated_user_from_token || User.find_by(email: params[:email]&.strip&.downcase)
        user&.send_confirmation_email unless user&.confirmed?

        head(:ok)
      end

      private

      # Try to identify the current user from a Bearer token without hard-failing.
      # Returns nil when no valid token is present so the public email-param path still works.
      def authenticated_user_from_token
        token = extract_token_from_header
        return unless token.present?

        decoded = JsonWebToken.decode(token)
        return unless decoded&.fetch(:type, nil) == "access"

        user = User.find_by(id: decoded[:user_id])
        return unless user && user.jti == decoded[:jti]

        user
      end

      public

      # PATCH /api/v1/email_confirmations/:token
      def update
        @user = User.find_by_token_for(:email_confirmation, params[:token])

        if @user.nil?
          render_error(
            "INVALID_TOKEN",
            message: "Email confirmation token is invalid or has expired",
            status: :unprocessable_content
          )
        elsif @user.confirmed?
          @message = "Email is already confirmed"
          @confirmed = true
        else
          @user.confirm_email!
          @message = "Email confirmed successfully"
          @confirmed = true
          @tokens = Auth::GenerateTokensService.call(@user).payload
        end
      end
    end
  end
end
