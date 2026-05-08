class SessionsController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!, only: [ :new, :create, :oauth_callback, :oauth_failure ]
  skip_before_action :check_legal_consent!
  skip_before_action :verify_authenticity_token, only: [ :oauth_callback, :oauth_failure ]

  # Only the custom app scheme is permitted as a mobile redirect target.
  # This prevents open-redirect attacks via a crafted mobile_redirect_uri.
  ALLOWED_MOBILE_SCHEMES = %w[vittio].freeze

  def new
    if params[:expired]
      flash.now[:alert] = "Your session has expired due to inactivity. Please sign in again."
    end
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      if user.confirmed?
        session[:user_id] = user.id
        session[:last_activity] = Time.current
        redirect_to "/dashboard"
      else
        # Store the email for the resend link in flash
        flash.now[:alert] = I18n.t("sessions.create.email_not_confirmed")
        flash.now[:unconfirmed_email] = user.email
        render :new, status: :unprocessable_content
      end
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    current_user.devices.where(platform: "web").update_all(active: false)
    reset_session
    redirect_to "/session/new", notice: "Signed out"
  end

  def oauth_callback
    auth = request.env["omniauth.auth"]
    mobile_redirect_uri = request.env["omniauth.params"]&.dig("mobile_redirect_uri")

    if auth.present?
      begin
        user = User.find_or_create_from_oauth(auth)
        if user.persisted?
          if mobile_redirect_uri.present?
            handle_mobile_oauth_success(user, mobile_redirect_uri)
          else
            session[:user_id] = user.id
            session[:last_activity] = Time.current
            redirect_to "/dashboard", notice: t("session.signed_in_successfully")
          end
        else
          redirect_oauth_failure(mobile_redirect_uri, "oauth_failed")
        end
      rescue => e
        Rails.logger.error "OAuth callback error: #{e.message}"
        redirect_oauth_failure(mobile_redirect_uri, "oauth_failed")
      end
    else
      redirect_oauth_failure(mobile_redirect_uri, "oauth_failed")
    end
  end

  def oauth_failure
    Rails.logger.error "OAuth failure: #{params[:message]}"
    mobile_redirect_uri = request.env["omniauth.params"]&.dig("mobile_redirect_uri")
    redirect_oauth_failure(mobile_redirect_uri, params[:message].presence || "oauth_failed")
  end

  def update_timezone
    if params[:timezone].present?
      session[:timezone] = params[:timezone]
      render json: { status: "ok", timezone: params[:timezone] }
    else
      render json: { status: "error", message: "No timezone provided" }, status: :bad_request
    end
  end

  private

  # Generate JWT tokens and redirect to the mobile deep-link URI.
  def handle_mobile_oauth_success(user, mobile_redirect_uri)
    unless valid_mobile_redirect_uri?(mobile_redirect_uri)
      Rails.logger.warn "Rejected invalid mobile_redirect_uri: #{mobile_redirect_uri}"
      redirect_to "/session/new", alert: t("session.oauth_failed")
      return
    end

    result = Auth::GenerateTokensService.call(user)
    if result.success?
      tokens = result.payload
      redirect_to append_query_params(
        mobile_redirect_uri, {
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_in: tokens[:expires_in].to_s,
        token_type: tokens[:token_type]
      }
      ), allow_other_host: true
    else
      Rails.logger.error "Token generation failed for OAuth mobile user #{user.id}"
      redirect_oauth_failure(mobile_redirect_uri, "token_generation_failed")
    end
  end

  # Route failures to the mobile deep-link URI (with error param) or the web login page.
  def redirect_oauth_failure(mobile_redirect_uri, error_code)
    if mobile_redirect_uri.present? && valid_mobile_redirect_uri?(mobile_redirect_uri)
      redirect_to append_query_params(mobile_redirect_uri, { error: error_code }),
        allow_other_host: true
    else
      redirect_to "/session/new", alert: t("session.oauth_failed")
    end
  end

  # Validate that the URI uses one of the allowed custom mobile app schemes.
  def valid_mobile_redirect_uri?(uri)
    parsed = URI.parse(uri.to_s)
    ALLOWED_MOBILE_SCHEMES.include?(parsed.scheme)
  rescue URI::InvalidURIError
    false
  end

  # Append query parameters to any URI string, preserving existing params.
  def append_query_params(base_uri, new_params)
    uri = URI.parse(base_uri.to_s)
    existing = URI.decode_www_form(uri.query || "")
    uri.query = URI.encode_www_form(existing + new_params.map { |k, v| [k.to_s, v.to_s] })
    uri.to_s
  rescue URI::InvalidURIError
    base_uri.to_s
  end
end
