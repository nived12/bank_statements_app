class EmailConfirmationsController < ApplicationController
  skip_before_action :authenticate!, only: [:show, :create]
  skip_before_action :check_legal_consent!

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
    # Always show same message to prevent email enumeration
    # Only send email if user exists and is not confirmed
    user = User.kept.find_by(email: params[:email]&.strip&.downcase)
    user&.send_confirmation_email unless user&.confirmed?

    redirect_to new_session_path, notice: I18n.t("email_confirmations.create.sent")
  end
end
