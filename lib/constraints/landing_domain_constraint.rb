module Constraints
  class LandingDomainConstraint
    def matches?(request)
      if Rails.env.production?
        # In production: only bare vitt.io (not app.vitt.io)
        landing_host = URI.parse(ENV.fetch("LANDING_DOMAIN", "https://vitt.io")).host || "vitt.io"
        request.host == landing_host
      else
        # In dev/test: match unauthenticated users (preserving original behavior)
        request.session[:user_id].blank?
      end
    end
  end
end
