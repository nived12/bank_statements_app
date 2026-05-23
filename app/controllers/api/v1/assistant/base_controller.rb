# frozen_string_literal: true

module Api
  module V1
    module Assistant
      class BaseController < Api::V1::BaseController
        before_action :require_confirmed_user!
        before_action :check_assistant_access!

        private

        # Premium gate. Mirrors check_ai_subscription! in TransactionsController, but
        # maps reasons to assistant-specific error codes when applicable.
        def check_assistant_access!
          result = current_user.assistant_access_result
          return if result[:allowed]

          code =
            case result[:reason]
            when :assistant_limit_reached then "ASSISTANT_LIMIT_REACHED"
            when :ai_limit_reached        then "AI_LIMIT_REACHED"
            else                               "SUBSCRIPTION_REQUIRED"
            end

          message = result[:message] || I18n.t("api.errors.subscription_required")
          render_error(code, message: message, status: :payment_required)
        end
      end
    end
  end
end
