require "rails_helper"

RSpec.describe ReminderMailer, type: :mailer do
  # NOTE: These specs are intentionally pending until User Notification Preferences feature is implemented
  # At that point, email sending will be enabled and these specs should be fully implemented

  describe "debt_payment_reminder" do
    it "renders the mailer" do
      skip "Will be implemented when User Notification Preferences feature is added"
      # TODO: Test mailer with actual debt, user, and date data
    end
  end

  describe "payment_overdue" do
    it "renders the mailer" do
      skip "Will be implemented when User Notification Preferences feature is added"
      # TODO: Test mailer with actual debt, user, and date data
    end
  end

  describe "savings_contribution_reminder" do
    it "renders the mailer" do
      skip "Will be implemented when User Notification Preferences feature is added"
      # TODO: Test mailer with actual saving, user, and progress data
    end
  end

  # The three mailers above are built but never sent (all call sites in
  # Reminders::GenerateRemindersService are commented out), so their specs stay
  # skipped. That left their templates with zero coverage — they were restyled
  # for the shared layout with nothing to catch a breakage until the day someone
  # enables the emails. These render them without asserting they are sent.
  describe "template rendering (emails still disabled)" do
    let(:user) { create(:user, first_name: "Ana") }
    let(:debt) { create(:debt, user: user, name: "Tarjeta BBVA") }
    let(:saving) { create(:saving, user: user, name: "Fondo de emergencia") }

    def expect_renders(mail)
      html = mail.html_part.body.decoded
      text = mail.text_part.body.decoded

      expect(html).to include("email-container")                      # shared layout applied
      expect(html).to include(I18n.t("mailer.footer.tagline"))
      expect(text).to include(I18n.t("mailer.footer.tagline"))

      # Both parts: asserting only that text_part exists misses HTML-only
      # migrations that leave the .text.erb views calling deleted keys.
      [ html, text ].each do |body|
        expect(body).not_to include("translation missing")
        expect(body).not_to include("translation_missing")
      end
      expect(text).not_to include("<span")
    end

    it "renders debt_payment_reminder" do
      expect_renders(described_class.debt_payment_reminder(debt, Date.current + 7, 1_850.00))
    end

    it "renders payment_overdue" do
      expect_renders(described_class.payment_overdue(debt))
    end

    it "renders savings_contribution_reminder" do
      expect_renders(
        described_class.savings_contribution_reminder(
          saving, { target: 5_000.00, achieved: 3_200.00, percentage: 64 }
        )
      )
    end
  end

  describe "trial_ending" do
    let(:user) { create(:user, first_name: "Ana", email: "ana@example.com") }

    it "sends to the user" do
      mail = described_class.trial_ending(user, 7)

      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(["noreply@vitt.io"])
    end

    it "has both HTML and text parts" do
      mail = described_class.trial_ending(user, 7)

      expect(mail.html_part).to be_present
      expect(mail.text_part).to be_present
    end

    it "links to the web subscription page" do
      mail = described_class.trial_ending(user, 7)

      expect(mail.html_part.body.decoded).to include(subscription_url)
      expect(mail.text_part.body.decoded).to include(subscription_url)
    end

    it "renders in Spanish regardless of the ambient locale" do
      I18n.with_locale(:en) do
        mail = described_class.trial_ending(user, 7)

        expect(mail.subject).to eq("Tu prueba de Vittio termina en 7 días")
      end
    end

    it "uses the branded layout" do
      mail = described_class.trial_ending(user, 7)

      expect(mail.html_part.body.decoded).to include("email-container")
      expect(mail.html_part.body.decoded).to include(I18n.t("mailer.footer.tagline", locale: :es))
    end

    describe "unsubscribe" do
      it "carries a working opt-out link in both parts" do
        mail = described_class.trial_ending(user, 7)
        url = unsubscribe_url(token: user.generate_token_for(:email_unsubscribe))

        expect(mail.html_part.body.decoded).to include(url)
        expect(mail.text_part.body.decoded).to include(url)
      end

      it "sets the RFC 8058 headers Gmail and Apple Mail read" do
        mail = described_class.trial_ending(user, 7)

        expect(mail["List-Unsubscribe"].to_s).to match(%r{\A<https?://.+/unsubscribe/.+>\z})
        expect(mail["List-Unsubscribe-Post"].to_s).to eq("List-Unsubscribe=One-Click")
      end

      it "issues a token that resolves back to the recipient" do
        mail = described_class.trial_ending(user, 7)
        token = mail["List-Unsubscribe"].to_s[%r{/unsubscribe/([^>]+)>}, 1]

        expect(User.find_by_token_for(:email_unsubscribe, token)).to eq(user)
      end
    end

    describe "urgency variants" do
      it "counts days when more than one day remains" do
        mail = described_class.trial_ending(user, 3)

        expect(mail.subject).to eq("Tu prueba de Vittio termina en 3 días")
        expect(mail.html_part.body.decoded).to include("Tu prueba termina en 3 días")
      end

      it "says tomorrow at one day left" do
        mail = described_class.trial_ending(user, 1)

        expect(mail.subject).to eq("Tu prueba de Vittio termina mañana")
        expect(mail.html_part.body.decoded).to include("Tu prueba termina mañana")
      end

      it "says today at zero days left" do
        mail = described_class.trial_ending(user, 0)

        expect(mail.subject).to eq("Tu prueba de Vittio termina hoy")
      end

      it "says today when the trial already lapsed earlier that day" do
        mail = described_class.trial_ending(user, -1)

        expect(mail.subject).to eq("Tu prueba de Vittio termina hoy")
      end
    end
  end
end
