# frozen_string_literal: true

module Api
  module V1
    module Assistant
      class UsageController < BaseController
        # Bypass the access check — usage endpoint should be readable even when at limit.
        skip_before_action :check_assistant_access!

        # GET /api/v1/assistant/usage
        def show
          @snapshot = ::Assistant::UsageMeter.new(current_user).snapshot
        end
      end
    end
  end
end
