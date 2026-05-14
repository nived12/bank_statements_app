class ApplicationMailer < ActionMailer::Base
  default from: "noreply@vitt.io"
  layout "mailer"

  helper_method :logo_url

  def logo_url
    opts = Rails.application.config.action_mailer.default_url_options.symbolize_keys
    protocol = (opts[:protocol] || (Rails.env.production? ? "https" : "http")).to_s.sub(%r{://\z}, "")
    host = opts[:host].to_s
    port = opts[:port]
    host_with_port = port.present? ? "#{host}:#{port}" : host
    ActionController::Base.helpers.asset_url("vittio_logo.png", host: host_with_port, protocol:)
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
