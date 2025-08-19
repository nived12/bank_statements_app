require "pagy"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include LocaleConcern
  include Pagy::Backend

  helper_method :current_user, :current_locale, :pagy

  before_action :authenticate!
  before_action :check_session_timeout, if: :current_user
  before_action :redirect_to_spanish_if_no_locale

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def current_locale
    I18n.locale
  end

  def authenticate!
    redirect_to "/session/new", alert: "Please sign in" unless current_user
  end

  def check_session_timeout
    # Only check session timeout in production environment
    return unless Rails.env.production?
    return unless session[:last_activity]

    timeout_minutes = 10
    timeout_threshold = timeout_minutes.minutes.ago

    if session[:last_activity] < timeout_threshold
      reset_session
      redirect_to "/session/new", alert: "Session expired due to inactivity. Please sign in again."
      return
    end

    # Update last activity timestamp
    session[:last_activity] = Time.current
  end

  def redirect_to_spanish_if_no_locale
    # Only redirect if no locale is specified and we're not already on a locale-specific path
    return if params[:locale].present?
    return if request.path.start_with?("/es/", "/en/")

    # Redirect to Spanish locale by default
    redirect_to "/es#{request.path}"
  end
end
