class PasswordResetsController < ApplicationController
  skip_before_action :authenticate!, only: [:new, :create, :edit, :update]
  layout "authentication"

  before_action :set_user_by_token, only: [:edit, :update]

  def new; end

  def create
    user = User.find_by(email: params[:email]&.strip&.downcase)

    # Send email only if user exists and can reset password
    if user&.can_reset_password?
      ApplicationMailer.password_reset_email(user).deliver_later
    end

    # Always show same message to prevent email enumeration
    redirect_to new_session_path, notice: t("password_resets.create.notice")
  end

  def edit; end

  def update
    if @user.update(password_params)
      redirect_to new_session_path, notice: t("password_resets.update.success")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user_by_token
    # Rails 8 built-in method: finds user by token, validates signature and expiration
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_reset_path, alert: t("password_resets.edit.invalid_token")
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
