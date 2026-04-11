class UserSettingsController < ApplicationController
  before_action :authenticate!

  def update
    settings = current_user.user_settings
    settings.theme = params[:theme] if params[:theme].present?
    if settings.save
      head :ok
    else
      render json: { error: settings.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
