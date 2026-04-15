class LandingController < ApplicationController
  layout "landing"
  skip_before_action :authenticate!
  helper_method :app_sign_in_url

  def index
    @waitlist = Waitlist.new
  end

  private

  def app_sign_in_url
    if Rails.env.production?
      "#{ENV.fetch("APP_DOMAIN", "https://app.vitt.io")}/session/new"
    else
      new_session_path
    end
  end
end
