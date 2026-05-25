# frozen_string_literal: true

module Api
  module V1
    # Public health probe for uptime monitors and load balancers.
    # No auth, no legal consent — must work even when the DB is down for
    # consent metadata. The endpoint intentionally does not touch the DB.
    class HealthController < BaseController
      VERSION = "1.0.0"

      skip_before_action :authenticate_api_user!
      skip_before_action :require_legal_consent!

      def show
        @status  = "ok"
        @version = VERSION
        @time    = Time.current.iso8601
      end
    end
  end
end
