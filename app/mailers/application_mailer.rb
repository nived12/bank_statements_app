class ApplicationMailer < ActionMailer::Base
  default from: "noreply@vittio.io"
  layout "mailer"

  def password_reset_email(user)
    @user = user
    # Rails 8 built-in method: generates cryptographically signed token that expires in 15 minutes
    @token = user.password_reset_token
    @reset_url = edit_password_reset_url(@token)

    mail(
      to: @user.email,
      subject: I18n.t("password_resets.email.subject")
    )
  end

  def confirmation_email(user)
    @user = user
    @confirmation_url = email_confirmation_url(user.confirmation_token)

    mail(
      to: @user.email,
      subject: I18n.t("email_confirmations.email.subject")
    )
  end
end
