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
      before_action :require_confirmed_user!, only: [:destroy]

      # DELETE /api/v1/user
      # Archives the user account (soft delete). Hard deletion is reserved
      # for the `rake users:hard_delete` task on explicit LFPDPPP request.
      def destroy
        result = Users::Archiver.call(user: current_user)

        if result.success?
          head(:no_content)
        else
          render_error(
            "DELETE_FAILED",
            message: "Failed to delete account",
            status: :unprocessable_content
          )
        end
      end

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

      # PATCH /api/v1/user/avatar
      # Accepts multipart/form-data with an `avatar` file field.
      def update_avatar
        @user = current_user

        unless params[:avatar].present?
          render_error("MISSING_AVATAR", message: "No avatar file provided", status: :unprocessable_content)
          return
        end

        @user.avatar_image.attach(params[:avatar])

        if @user.avatar_image.attached?
          render :show
        else
          render_error("AVATAR_UPLOAD_FAILED", message: "Avatar could not be saved", status: :unprocessable_content)
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
