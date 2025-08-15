class SessionsController < ApplicationController
  skip_before_action :authenticate!, only: [ :new, :create ]

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
      redirect_to "/dashboard", notice: "Signed in successfully"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
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
end
