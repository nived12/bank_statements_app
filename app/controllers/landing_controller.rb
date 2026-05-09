class LandingController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!
  skip_before_action :check_legal_consent!
  helper_method :app_sign_in_url

  def index
    @waitlist = Waitlist.new
  end

  private

  def app_sign_in_url
    if Rails.env.production?
      app_host = begin
        URI.parse(Rails.configuration.x.app_domain).host
      rescue URI::InvalidURIError
        "app.vitt.io"
      end
      new_session_url(host: app_host, protocol: "https")
    else
      new_session_path
    end
  end
end
