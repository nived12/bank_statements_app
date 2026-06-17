# frozen_string_literal: true

# Shared setup for the public marketing pages (landing + pricing). Both use the
# self-contained "landing" layout, skip auth/legal gates, and render copy
# inline-bilingual with the initial language driven by `?locale=`.
module MarketingLayout
  extend ActiveSupport::Concern

  included do
    layout "landing"
    skip_before_action :authenticate!
    skip_before_action :check_legal_consent!
    helper_method :app_sign_in_url
    before_action :set_marketing_locale
  end

  private

  def set_marketing_locale
    @locale = params[:locale].in?(%w[en es]) ? params[:locale] : "es"
  end

  # In production the marketing site lives on vitt.io while the app lives on a
  # separate host, so sign-in must be an absolute URL to the app domain.
  def app_sign_in_url
    return new_session_path unless Rails.env.production?

    app_host = begin
      URI.parse(Rails.configuration.x.app_domain).host
    rescue URI::InvalidURIError
      "app.vitt.io"
    end
    new_session_url(host: app_host, protocol: "https")
  end
end
