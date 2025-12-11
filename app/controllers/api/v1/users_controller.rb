# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::UsersController
    # Handles user profile management for API clients
    #
    # Endpoints:
    # - GET /api/v1/user - Get current user profile
    # - PATCH /api/v1/user - Update user profile
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
            status: :unprocessable_entity,
            details: format_validation_errors(@user.errors)
          )
        end
      end

      private

      def user_params
        params.require(:user).permit(:first_name, :last_name, :avatar_url)
      end
    end
  end
end
