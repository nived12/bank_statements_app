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

  # GET /profile/confirm_delete — typed-confirmation page
  def confirm_delete
  end

  # DELETE /profile — archives the account
  def destroy
    expected = I18n.locale == :es ? "ELIMINAR" : "DELETE"
    if params[:confirm].to_s.strip != expected
      flash[:alert] = t("profile.delete.confirm_mismatch")
      redirect_to confirm_delete_profile_path and return
    end

    result = Users::Archiver.call(user: current_user)

    if result.success?
      reset_session
      redirect_to new_session_path, notice: t("profile.delete.success")
    else
      flash[:alert] = t("profile.delete.failed")
      redirect_to profile_path
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
