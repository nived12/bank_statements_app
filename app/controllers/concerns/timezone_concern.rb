# frozen_string_literal: true

##
# TimezoneConcern
# Handles timezone detection and setting based on user's browser timezone
#
module TimezoneConcern
  extend ActiveSupport::Concern

  included do
    around_action :set_timezone, if: :current_user
    before_action :set_timezone_for_request, if: :current_user
  end

  private

  def set_timezone(&block)
    timezone = detect_timezone
    Time.use_zone(timezone, &block)
  end

  def set_timezone_for_request
    timezone = detect_timezone
    Time.zone = timezone if timezone
  end

  def detect_timezone
    # Try to get timezone from various sources in order of preference
    timezone = params[:timezone] ||           # From JavaScript timezone detection
               session[:timezone] ||          # From stored session
               browser_timezone ||            # From browser headers
               system_timezone ||             # From system
               "America/Mexico_City"          # Fallback to Mexico City (more likely for this app)

    # Store in session for future requests
    session[:timezone] = timezone if timezone != session[:timezone]

    timezone
  end

  def browser_timezone
    # Try to detect from browser headers (some browsers send this)
    request.headers["HTTP_X_TIMEZONE"] ||
    request.headers["HTTP_X_CLIENT_TIMEZONE"]
  end

  def system_timezone
    # Returning Time.zone here leaks the global app default (UTC) into requests
    # before user/browser timezone has been detected. That causes date defaults
    # to drift for users west of UTC around midnight. Keep this nil so we use
    # explicit client/session timezone or the deterministic Mexico City fallback.
    nil
  end
end
