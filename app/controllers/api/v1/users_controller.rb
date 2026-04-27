# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::UsersController
    # Handles user profile management for API clients
    #
    # Endpoints:
    # - GET /api/v1/user - Get current user profile
    # - PATCH /api/v1/user - Update user profile (first_name, last_name, email, avatar_url)
    # - PATCH /api/v1/user/password - Change password (non-OAuth users only)
    #
    class UsersController < BaseController
      # GET /api/v1/user
      def show
        @user = current_user
      end

      # PATCH /api/v1/user
      def update
        @user = current_user

        if @user.update(user_params)
          render :show
        else
          render_error(
            "VALIDATION_ERROR",
            message: "User profile could not be updated",
            status: :unprocessable_content,
            details: format_validation_errors(@user.errors)
          )
        end
      end

      # PATCH /api/v1/user/password
      def update_password
        @user = current_user

        if @user.oauth_user?
          render_error(
            "OAUTH_ACCOUNT",
            message: "Password cannot be changed for accounts linked via Google Sign-In",
            status: :unprocessable_content
          )
          return
        end

        unless @user.authenticate(password_params[:current_password])
          render_error(
            "INVALID_CURRENT_PASSWORD",
            message: "Current password is incorrect",
            status: :unprocessable_content
          )
          return
        end

        if @user.update(
          password: password_params[:password],
          password_confirmation: password_params[:password_confirmation]
        )
          msg = I18n.t("api.users.password_updated")
          render json: { data: { message: msg }, message: msg }, status: :ok
        else
          render_error(
            "VALIDATION_ERROR",
            message: "Password could not be updated",
            status: :unprocessable_content,
            details: format_validation_errors(@user.errors)
          )
        end
      end

      private

      def user_params
        params.require(:user).permit(:first_name, :last_name, :avatar_url)
      end

      def password_params
        params.require(:user).permit(:current_password, :password, :password_confirmation)
      end
    end
  end
end
