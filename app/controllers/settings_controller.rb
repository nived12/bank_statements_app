class SettingsController < ApplicationController
  before_action :load_user_setting

  def show
  end

  def update
    if @user_setting.update(settings_params)
      respond_to do |format|
        format.html { redirect_to settings_path, notice: t("settings.saved") }
        format.turbo_stream { flash.now[:notice] = t("settings.saved") }
      end
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def load_user_setting
    @user_setting = current_user.user_setting
  end

  def settings_params
    params.require(:user_setting).permit(:analytics_enabled)
  end
end
