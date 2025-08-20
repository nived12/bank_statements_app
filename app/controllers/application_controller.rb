require "pagy"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include LocaleConcern
  include Pagy::Backend

  helper_method :current_user, :current_locale, :pagy

  before_action :authenticate!
  before_action :check_session_timeout, if: :current_user
  before_action :set_locale_from_url

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def current_locale
    I18n.locale
  end

  def authenticate!
    redirect_to new_session_path, alert: "Please sign in" unless current_user
  end

  def check_session_timeout
    # Only check session timeout in production environment
    return unless Rails.env.production?
    return unless session[:last_activity]

    timeout_minutes = 10
    timeout_threshold = timeout_minutes.minutes.ago

    if session[:last_activity] < timeout_threshold
      reset_session
      redirect_to new_session_path, alert: "Session expired due to inactivity. Please sign in again."
      return
    end

    # Update last activity timestamp
    session[:last_activity] = Time.current
  end

    def set_locale_from_url
    # Extract locale from URL path or default to Spanish
    locale = params[:locale] || extract_locale_from_path || "es"

    # Set the locale without redirecting
    I18n.locale = locale.to_sym
  end

  def extract_locale_from_path
    # Check if path starts with a known locale
    if request.path.start_with?("/en/")
      "en"
    elsif request.path.start_with?("/es/")
      "es"
    else
      nil # No locale in path, will default to Spanish
    end
  end
end
