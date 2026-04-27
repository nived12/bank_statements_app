# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::PasswordResetsController
    # Handles password reset requests for API clients
    #
    # Endpoints:
    # - POST /api/v1/password_resets - Request password reset
    # - PATCH /api/v1/password_resets/:token - Reset password with token
    #
    class PasswordResetsController < BaseController
      skip_before_action :authenticate_api_user!

      # POST /api/v1/password_resets
      def create
        email = params.dig(:user, :email) || params[:email]
        user  = User.find_by(email: email&.strip&.downcase)

        # Tell the caller explicitly when the account uses OAuth — they need
        # to sign in with Google instead.  We can reveal this safely because
        # the email was just submitted by the person who owns it.
        if user&.oauth_user?
          return render_error(
            "OAUTH_ACCOUNT",
            message: "This account uses Google Sign-In. No password reset is needed.",
            status: :unprocessable_entity
          )
        end

        if user&.can_reset_password?
          ApplicationMailer.password_reset_email(user).deliver_later
        end

        head(:ok)
      end

      # PATCH /api/v1/password_resets/:token
      def update
        @user = User.find_by_password_reset_token!(params[:token])

        if @user.update(password_params)
          head(:ok)
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Password reset failed",
            status: :unprocessable_content,
            details: format_validation_errors(@user.errors)
          )
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        render_error(
          "INVALID_TOKEN",
          message: "Password reset token is invalid or has expired",
          status: :unprocessable_content
        )
      end

      private

      def password_params
        params.require(:user).permit(:password, :password_confirmation)
      end
    end
  end
end
