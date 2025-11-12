class ApplicationMailer < ActionMailer::Base
  default from: "noreply@vittio.app"
  layout "mailer"

  def password_reset_email(user)
    @user = user
    @token = user.password_reset_token
    @reset_url = edit_password_reset_url(@token)

    mail(
      to: @user.email,
      subject: I18n.t("password_resets.email.subject")
    )
  end
end
