class EmailConfirmationsController < ApplicationController
  skip_before_action :authenticate!, only: [:show, :create]

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user
      if user.confirmed?
        flash[:notice] = I18n.t("email_confirmations.show.already_confirmed")
      else
        user.confirm_email!
        flash[:notice] = I18n.t("email_confirmations.show.success")
      end

      redirect_to new_session_path
    else
      flash[:alert] = I18n.t("email_confirmations.show.invalid_or_expired")
      redirect_to new_session_path
    end
  end

  def create
    user = User.find_by(email: params[:email]&.strip&.downcase)

    if user && !user.confirmed?
      user.send_confirmation_email
      redirect_to new_session_path, notice: I18n.t("email_confirmations.create.sent")
    else
      # Always show same message to prevent email enumeration
      redirect_to new_session_path, notice: I18n.t("email_confirmations.create.sent")
    end
  end
end
