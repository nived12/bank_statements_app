class UsersController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!, only: %i[new create]
  skip_before_action :check_legal_consent!

  def new
    @user = User.new(email: params[:email].to_s.strip.presence)
  end

  def create
    @user = User.new(user_params)
    if @user.save
      @user.send_confirmation_email
      ::Analytics.capture(distinct_id: @user.id, event: "user_signed_up")
      # Auto-login on signup (matches API behavior). Email confirmation is
      # enforced per-action via require_confirmed_user! on destructive
      # endpoints, not as a gate on entering the platform.
      session[:user_id] = @user.id
      session[:last_activity] = Time.current
      redirect_to dashboard_path, notice: I18n.t("users.create.welcome")
    else
      flash.now[:alert] = @user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user)
          .permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
