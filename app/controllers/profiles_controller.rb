class ProfilesController < ApplicationController
  def show
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: t("profile.saved")
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def profile_params
    permitted = params.require(:user).permit(:first_name, :last_name)
    if params[:user][:avatar_image].present?
      permitted = params.require(:user).permit(:first_name, :last_name, :avatar_image)
    end
    permitted
  end
end
