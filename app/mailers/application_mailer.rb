class ApplicationMailer < ActionMailer::Base
  # Use verified domain for all emails (vitt.io is verified in Resend)
  # Development can also use the verified domain to test sending to any email address
  default from: "noreply@vitt.io"
  layout "mailer"

  helper_method :logo_url

  def logo_url
    # Use production URL for logo
    # In development, email clients can't access localhost, so we use a placeholder
    # or you can upload to imgbb.com and use that URL for testing
    if Rails.env.production?
      "https://#{ENV.fetch("RAILWAY_PUBLIC_DOMAIN", "app.vittio.io")}/vittio1.png"
    else
      "https://i.ibb.co/9m3vppkH/vittio1.png"
    end
  end

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
    # Rails 8 built-in method: generates cryptographically signed token that expires in 24 hours
    @token = user.generate_token_for(:email_confirmation)
    @confirmation_url = email_confirmation_url(@token)

    mail(
      to: @user.email,
      subject: I18n.t("email_confirmations.email.subject")
    )
  end
end
