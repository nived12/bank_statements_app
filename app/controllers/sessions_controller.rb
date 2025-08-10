class SessionsController < ApplicationController
  skip_before_action :authenticate!, only: [ :new, :create ]

  def new; end

  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to "/statement_files/new", notice: "Signed in"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to "/session/new", notice: "Signed out"
  end
end
