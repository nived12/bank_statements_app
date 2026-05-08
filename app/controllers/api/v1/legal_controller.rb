# frozen_string_literal: true

module Api
  module V1
    class LegalController < BaseController
      # Skip the consent guard — these are the endpoints that handle consent
      skip_before_action :require_legal_consent!

      def accept
        result = Legal::AcceptConsent.call(
          user: current_user,
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )

        if result.success?
          @version = result.payload[:version]
          @accepted_at = result.payload[:accepted_at]
          render :accept, status: :ok
        else
          render_error(
            "CONSENT_FAILED",
            message: result.errors.full_messages.join(", "),
            status: :unprocessable_entity
          )
        end
      end

      def status
        @user = current_user
        @consent_current = @user.legal_consent_current?
        render :status, status: :ok
      end
    end
  end
end
