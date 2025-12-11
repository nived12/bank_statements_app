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
        user = User.find_by(email: params[:email]&.strip&.downcase)

        if user&.can_reset_password?
          ApplicationMailer.password_reset_email(user).deliver_later
        end
      end

      # PATCH /api/v1/password_resets/:token
      def update
        @user = User.find_by_password_reset_token!(params[:token])

        unless @user.update(password_params)
          render_error(
            "VALIDATION_ERROR",
            message: "Password reset failed",
            status: :unprocessable_entity,
            details: format_validation_errors(@user.errors)
          )
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        render_error(
          "INVALID_TOKEN",
          message: "Password reset token is invalid or has expired",
          status: :unprocessable_entity
        )
      end

      private

      def password_params
        params.require(:user).permit(:password, :password_confirmation)
      end
    end
  end
end
