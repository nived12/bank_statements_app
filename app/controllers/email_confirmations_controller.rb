class EmailConfirmationsController < ApplicationController
  skip_before_action :authenticate!, only: [:show]

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user
      user.confirm_email!
      flash[:notice] = I18n.t("email_confirmations.show.success")
      redirect_to new_session_path
    else
      flash[:alert] = I18n.t("email_confirmations.show.invalid_or_expired")
      redirect_to new_session_path
    end
  end
end
