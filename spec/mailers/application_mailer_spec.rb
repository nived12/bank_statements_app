require "rails_helper"

RSpec.describe ApplicationMailer, type: :mailer do
  describe "#password_reset_email" do
    let(:user) { create(:user, first_name: "John", email: "john@example.com") }
    let(:mail) { ApplicationMailer.password_reset_email(user) }

    it "sends to the correct recipient" do
      expect(mail.to).to eq([user.email])
    end

    it "sends from the correct sender" do
      expect(mail.from).to eq(["noreply@vitt.io"])
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

  describe "#confirmation_email" do
    let(:user) { create(:user, first_name: "Jane", email: "jane@example.com") }
    let(:mail) { ApplicationMailer.confirmation_email(user) }

    it "sends to the correct recipient" do
      expect(mail.to).to eq([user.email])
    end

    it "sends from the correct sender" do
      expect(mail.from).to eq(["noreply@vitt.io"])
    end

    it "has correct subject" do
      expect(mail.subject).to eq(I18n.t("email_confirmations.email.subject"))
    end

    it "includes the user's first name" do
      expect(mail.body.encoded).to include(user.first_name)
    end

    it "includes a confirmation URL with token" do
      html_body = mail.html_part.body.decoded
      expect(html_body).to match(/email_confirmations\/[\w\-=]+/)
    end

    it "has both HTML and text parts" do
      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it "includes Vittio branding" do
      expect(mail.body.encoded).to include("Vittio")
    end

    it "includes welcome message" do
      html_body = mail.html_part.body.decoded
      text_body = mail.text_part.body.decoded

      # Check in either HTML or text part
      expect(html_body + text_body).to include(user.first_name)
    end
  end

  # Every user receives these two, so both parts need content assertions —
  # not just that text_part exists.
  describe "both parts of every ApplicationMailer email" do
    let(:user) { create(:user, first_name: "Ana") }

    {
      "password_reset_email" => ->(u) { ApplicationMailer.password_reset_email(u) },
      "confirmation_email" => ->(u) { ApplicationMailer.confirmation_email(u) }
    }.each do |name, build|
      context name do
        let(:mail) { build.call(user) }
        let(:html) { mail.html_part.body.decoded }
        let(:text) { mail.text_part.body.decoded }

        it "renders the shared footer in both parts" do
          expect(html).to include(I18n.t("mailer.footer.tagline"))
          expect(text).to include(I18n.t("mailer.footer.tagline"))
          expect(text).to include(I18n.t("mailer.footer.help"))
        end

        it "has no missing translations in either part" do
          [ html, text ].each do |body|
            expect(body).not_to include("translation missing")
            expect(body).not_to include("translation_missing")
          end
        end

        it "keeps HTML out of the plain-text part" do
          expect(text).not_to include("<span")
          expect(text).not_to include("<div")
          expect(text).not_to include("<!DOCTYPE")
        end
      end
    end
  end
end
