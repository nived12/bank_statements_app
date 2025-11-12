require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  describe "#password_reset_email" do
    let(:user) { create(:user, first_name: "John", email: "john@example.com") }
    let(:mail) { ApplicationMailer.password_reset_email(user) }

    it "sends to the correct recipient" do
      expect(mail.to).to eq([user.email])
    end

    it "sends from the correct sender" do
      expect(mail.from).to eq(["noreply@vittio.app"])
    end

    it "has correct subject" do
      expect(mail.subject).to eq(I18n.t("password_resets.email.subject"))
    end

    it "includes the user's first name" do
      expect(mail.body.encoded).to include(user.first_name)
    end

    it "includes a password reset URL with token" do
      # Check in HTML part (decoded)
      html_body = mail.html_part.body.decoded
      expect(html_body).to match(/password_resets\/[\w\-=]+\/edit/)
    end

    it "has both HTML and text parts" do
      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it "includes Vittio branding" do
      expect(mail.body.encoded).to include("Vittio")
    end
  end
end
