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
