require "pagy"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include LocaleConcern
  include TimezoneConcern
  include Pagy::Backend

  helper_method :current_user, :current_locale, :pagy

  before_action :authenticate!
  before_action :check_session_timeout, if: :current_user
  before_action :set_current_user
  after_action :reset_current_user

  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from StandardError, with: :handle_internal_server_error

  # Override rescue_with_handler to ensure proper error handling for before_action callbacks
  def rescue_with_handler(exception)
    case exception
    when ActiveRecord::RecordNotFound
      handle_not_found(exception)
    when StandardError
      handle_internal_server_error(exception)
    else
      super
    end
  end

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

    timeout_period = 2.weeks
    timeout_threshold = timeout_period.ago

    if session[:last_activity] < timeout_threshold
      reset_session
      redirect_to new_session_path, alert: "Session expired due to inactivity. Please sign in again."
      return
    end

    # Update last activity timestamp
    session[:last_activity] = Time.current
  end

  def set_current_user
    Current.user = current_user if current_user
  end

  def reset_current_user
    Current.reset
  end

  def default_url_options(options = {})
    options ||= {}
    # Only add locale query param if it's not the default (es)
    options[:locale] = I18n.locale if I18n.locale != I18n.default_locale
    options
  end

  def handle_not_found(exception)
    Rails.logger.warn "Record not found: #{exception.class} - #{exception.message}"
    respond_to do |format|
      format.html {
        flash.now[:alert] = "The requested resource was not found."
        render "errors/not_found", status: :not_found, layout: "application"
      }
      format.json { render json: { error: "Not Found" }, status: :not_found }
    end
  end

  def handle_internal_server_error(exception)
    Rails.logger.error "Internal server error: #{exception.class} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace

    respond_to do |format|
      format.html {
        flash.now[:alert] = "An error occurred. Please try again."
        render "errors/internal_server_error", status: :internal_server_error, layout: "application"
      }
      format.json { render json: { error: "Internal Server Error" }, status: :internal_server_error }
    end
  end
end
