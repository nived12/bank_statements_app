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

      # POST /api/v1/login
      # Authenticate user and return JWT tokens
      def login
        user = User.find_by(email: login_params[:email]&.downcase)

        unless user&.authenticate(login_params[:password])
          @error_message = "Invalid email or password"
          @error_code = "INVALID_CREDENTIALS"
          return render "api/v1/shared/error", status: :unauthorized
        end

        # Check if email is confirmed
        unless user.confirmed?
          @error_message = "Please confirm your email address before logging in"
          @error_code = "EMAIL_NOT_CONFIRMED"
          return render "api/v1/shared/error", status: :forbidden
        end

        # Generate tokens
        result = Auth::GenerateTokensService.call(user)

        if result.success?
          @tokens = result.payload
          @user = user
          @message = "Successfully logged in"
        else
          @error_message = "Login failed"
          @error_code = "TOKEN_GENERATION_FAILED"
          @error_details = result.errors.full_messages
          render "api/v1/shared/error", status: :unprocessable_entity
        end
      end

      # POST /api/v1/signup
      # Create new user account
      def signup
        user = User.new(signup_params)
        user.email = user.email&.downcase

        if user.save
          # Send confirmation email
          user.send_confirmation_email unless user.oauth_user?

          # Generate tokens (user can use the app even before confirming)
          result = Auth::GenerateTokensService.call(user)

          if result.success?
            @tokens = result.payload
            @user = user
            @message = "Account created successfully"
            render(status: :created)
          else
            @error_message = "Failed to generate authentication tokens"
            @error_code = "TOKEN_GENERATION_FAILED"
            render "api/v1/shared/error", status: :unprocessable_entity
          end
        else
          @error_message = "Failed to create account"
          @error_code = "VALIDATION_ERROR"
          @error_details = format_validation_errors(user.errors)
          render "api/v1/shared/error", status: :unprocessable_entity
        end
      end

      # POST /api/v1/refresh
      # Refresh access token using refresh token
      def refresh
        refresh_token = params[:refresh_token]

        if refresh_token.blank?
          @error_message = "Refresh token is required"
          @error_code = "REFRESH_TOKEN_REQUIRED"
          return render("api/v1/shared/error", status: :bad_request)
        end

        result = Auth::RefreshTokensService.call(refresh_token)

        if result.success?
          @tokens = result.payload
          @message = "Token refreshed successfully"
        else
          @error_message = "Failed to refresh token"
          @error_code = "REFRESH_FAILED"
          @error_details = result.errors.full_messages
          render("api/v1/shared/error", status: :unauthorized)
        end
      end

      # DELETE /api/v1/logout
      # Revoke all user tokens (logout)
      def logout
        result = Auth::RevokeTokensService.call(current_user)

        if result.success?
          @message = "Successfully logged out"
        else
          @error_message = "Failed to logout"
          @error_code = "LOGOUT_FAILED"
          @error_details = result.errors.full_messages
          render("api/v1/shared/error", status: :unprocessable_entity)
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
