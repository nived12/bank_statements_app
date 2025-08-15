class UsersController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      session[:last_activity] = Time.current
      redirect_to "/dashboard", notice: "Welcome, #{@user.first_name}!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user)
          .permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
