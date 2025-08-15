class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include LocaleConcern

  helper_method :current_user, :current_locale

  before_action :authenticate!
  before_action :check_session_timeout, if: :current_user

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
    return unless session[:last_activity]

    timeout_minutes = 5
    timeout_threshold = timeout_minutes.minutes.ago

    if session[:last_activity] < timeout_threshold
      reset_session
      redirect_to "/session/new", alert: "Session expired due to inactivity. Please sign in again."
      return
    end

    # Update last activity timestamp
    session[:last_activity] = Time.current
  end
end
