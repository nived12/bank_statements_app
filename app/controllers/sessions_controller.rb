class SessionsController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!, only: [ :new, :create, :oauth_callback, :oauth_failure ]
  skip_before_action :verify_authenticity_token, only: [ :oauth_callback, :oauth_failure ]

  def new
    if params[:expired]
      flash.now[:alert] = "Your session has expired due to inactivity. Please sign in again."
    end
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      session[:last_activity] = Time.current
      redirect_to "/dashboard"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to "/session/new", notice: "Signed out"
  end

  def heartbeat
    # Update last activity timestamp
    session[:last_activity] = Time.current
    render json: { status: "ok", timestamp: Time.current }
  end

  def oauth_callback
    auth = request.env["omniauth.auth"]

    if auth.present?
      begin
        user = User.find_or_create_from_oauth(auth)
        if user.persisted?
          session[:user_id] = user.id
          session[:last_activity] = Time.current
          redirect_to "/dashboard", notice: t("session.signed_in_successfully")
        else
          redirect_to "/session/new", alert: t("session.oauth_failed")
        end
      rescue => e
        Rails.logger.error "OAuth callback error: #{e.message}"
        redirect_to "/session/new", alert: t("session.oauth_failed")
      end
    else
      redirect_to "/session/new", alert: t("session.oauth_failed")
    end
  end

  def oauth_failure
    Rails.logger.error "OAuth failure: #{params[:message]}"
    redirect_to "/session/new", alert: t("session.oauth_failed")
  end

  def update_timezone
    if params[:timezone].present?
      session[:timezone] = params[:timezone]
      render json: { status: "ok", timezone: params[:timezone] }
    else
      render json: { status: "error", message: "No timezone provided" }, status: :bad_request
    end
  end
end
