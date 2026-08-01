# Preview all emails at http://localhost:3000/rails/mailers/application_mailer
#
# Both emails embed a signed token, which requires a persisted user.
class ApplicationMailerPreview < ActionMailer::Preview
  def confirmation_email
    ApplicationMailer.confirmation_email(sample_user)
  end

  def password_reset_email
    ApplicationMailer.password_reset_email(sample_user)
  end

  private

  def sample_user
    User.first or raise "Preview needs at least one user — run bin/rails db:seed"
  end
end
