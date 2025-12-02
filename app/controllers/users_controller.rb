class UsersController < ApplicationController
  layout "authentication"
  skip_before_action :authenticate!, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      @user.send_confirmation_email
      redirect_to new_session_path, notice: I18n.t("users.create.check_email")
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
