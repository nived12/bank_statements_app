module Constraints
  class LandingDomainConstraint
    def matches?(request)
      if Rails.env.production?
        # In production: only bare vitt.io (not app.vitt.io)
        request.host == landing_host
      else
        # In dev/test: match unauthenticated users (preserving original behavior).
        # Uses session[:user_id] consistent with AuthenticatedConstraint.
        request.session[:user_id].blank?
      end
    end

    private

    def landing_host
      return @landing_host if defined?(@landing_host)

      @landing_host = URI.parse(Rails.configuration.x.landing_domain).host
    rescue URI::InvalidURIError
      @landing_host = "vitt.io"
    end
  end
end
