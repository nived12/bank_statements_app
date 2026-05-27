# frozen_string_literal: true

module Api
  module V1
    class UserSettingsController < BaseController
      def show
        @settings = current_user.user_setting || current_user.create_user_setting!
        render "api/v1/user_settings/show"
      end

      def update
        @settings = current_user.user_setting || current_user.create_user_setting!
        permitted = settings_params

        permitted.each do |key, value|
          @settings.public_send(:"#{key}=", ActiveModel::Type::Boolean.new.cast(value))
        end

        if @settings.save
          render "api/v1/user_settings/show"
        else
          render_error(
            "VALIDATION_ERROR",
            message: @settings.errors.full_messages.join(", "),
            status: :unprocessable_content
          )
        end
      end

      private

      def settings_params
        params.require(:settings).permit(
          :notify_statement_imports,
          :notify_goal_milestones,
          :notify_debt_reminders,
          :analytics_enabled,
          :analytics_notice_seen_at
        )
      end
    end
  end
end
