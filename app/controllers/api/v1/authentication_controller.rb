# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::AuthenticationController
    # Handles JWT authentication for mobile/API clients
    #
    # Endpoints:
    # - POST /api/v1/login - Login with email/password
    # - POST /api/v1/signup - Create new user account
    # - POST /api/v1/refresh - Refresh access token
    # - DELETE /api/v1/logout - Revoke all tokens
    #
    class AuthenticationController < BaseController
      skip_before_action :authenticate_api_user!, only: [:login, :signup, :refresh]
      skip_before_action :require_legal_consent!

      # POST /api/v1/login
      # Authenticate user and return JWT tokens
      def login
        user = User.find_by(email: login_params[:email]&.downcase)

        unless user&.authenticate(login_params[:password])
          return render_error(
            "INVALID_CREDENTIALS",
            message: "Invalid email or password",
            status: :unauthorized
          )
        end

        unless user.confirmed?
          return render_error(
            "EMAIL_NOT_CONFIRMED",
            message: "Please confirm your email address before logging in",
            status: :forbidden
          )
        end

        # Generate tokens
        result = Auth::GenerateTokensService.call(user)

        if result.success?
          @tokens = result.payload
          @user = user
        else
          render_error("TOKEN_GENERATION_FAILED", details: result.errors.full_messages)
        end
      end

      # POST /api/v1/signup
      # Create new user account
      def signup
        signup_hash = signup_params.to_h
        signup_hash[:email] = signup_hash[:email]&.downcase
        user = User.new(signup_hash)

        if user.save
          # Send confirmation email
          user.send_confirmation_email unless user.oauth_user?

          # Generate tokens (user can use the app even before confirming)
          result = Auth::GenerateTokensService.call(user)

          if result.success?
            @tokens = result.payload
            @user = user
            render(status: :created)
          else
            render_error("TOKEN_GENERATION_FAILED", details: result.errors.full_messages)
          end
        else
          render_error("VALIDATION_ERROR", details: format_validation_errors(user.errors))
        end
      end

      # POST /api/v1/refresh
      # Refresh access token using refresh token
      def refresh
        refresh_token = params[:refresh_token]

        if refresh_token.blank?
          return render_error(
            "REFRESH_TOKEN_REQUIRED",
            status: :bad_request
          )
        end

        result = Auth::RefreshTokensService.call(refresh_token)

        if result.success?
          @tokens = result.payload
        else
          render_error(
            "REFRESH_FAILED",
            status: :unauthorized,
            details: result.errors.full_messages
          )
        end
      end

      # DELETE /api/v1/logout
      # Revoke all user tokens (logout)
      def logout
        result = Auth::RevokeTokensService.call(current_user)

        if result.success?
          head(:ok)
        else
          render_error("LOGOUT_FAILED", details: result.errors.full_messages)
        end
      end

      private

      def login_params
        params.require(:user).permit(:email, :password)
      end

      def signup_params
        params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
      end
    end
  end
end
