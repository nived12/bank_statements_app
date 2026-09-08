require "rails_helper"

RSpec.describe AnnouncementMailer, type: :mailer do
  let(:user) { create(:user, first_name: "Ana", email: "ana@example.com") }

  let(:announcement) do
    Announcement.new(
      {
        "slug" => "prueba-diciembre",
        "subject" => "Extendimos tu prueba",
        "audience" => "all",
        "cta_label" => "Ir a mi cuenta",
        "cta_url" => "/subscription"
      },
      "Hola **{{first_name}}**, tu prueba llega hasta diciembre."
    )
  end

  before { allow(Announcement).to receive(:find).with("prueba-diciembre").and_return(announcement) }

  subject(:mail) { described_class.broadcast(user, "prueba-diciembre") }

  it "addresses the user with the announcement's subject" do
    expect(mail.to).to eq([user.email])
    expect(mail.subject).to eq("Extendimos tu prueba")
  end

  # The copy asks people to reply, so the sender has to be an address that
  # accepts one. Transactional mail still goes out as noreply@.
  it "comes from a real, replyable address" do
    expect(mail.from).to eq(["nivedvengilat@vitt.io"])
    expect(mail[:from].to_s).to include("Nived de Vittio")
  end

  it "renders the markdown body into both parts" do
    expect(mail.html_part.body.decoded).to include("<strong>Ana</strong>")
    expect(mail.text_part.body.decoded).to include("Hola **Ana**")
  end

  it "applies the shared Vittio layout" do
    expect(mail.html_part.body.decoded).to include("email-container")
    expect(mail.html_part.body.decoded).to include(I18n.t("mailer.footer.tagline", locale: :es))
  end

  it "renders the CTA from frontmatter as an absolute URL" do
    html = mail.html_part.body.decoded

    expect(html).to include("Ir a mi cuenta")
    expect(html).to match(%r{https?://[^"]+/subscription})
  end

  it "sends in Spanish regardless of the ambient locale" do
    I18n.with_locale(:en) do
      expect(mail.html_part.body.decoded).to include(I18n.t("mailer.footer.tagline", locale: :es))
    end
  end

  # RFC 8058. Without these Gmail and Apple Mail render no native unsubscribe
  # button, which is what bulk-sender reputation is judged on.
  it "sets the one-click unsubscribe headers" do
    expect(mail["List-Unsubscribe"].to_s).to match(%r{/unsubscribe/})
    expect(mail["List-Unsubscribe-Post"].to_s).to eq("List-Unsubscribe=One-Click")
  end

  it "includes an unsubscribe link in the body" do
    expect(mail.html_part.body.decoded).to match(%r{/unsubscribe/})
    expect(mail.text_part.body.decoded).to match(%r{/unsubscribe/})
  end

  # deliver_later serializes its arguments, which is why the mailer takes a slug
  # rather than the Announcement object. Passing the object raised only at send
  # time, so assert the contract holds.
  it "can be enqueued for later delivery" do
    expect { described_class.broadcast(user, "prueba-diciembre").deliver_later }
      .not_to raise_error
  end

  it "raises on a slug with no announcement file" do
    allow(Announcement).to receive(:find).with("fantasma").and_return(nil)

    expect { described_class.broadcast(user, "fantasma").deliver_now }
      .to raise_error(ArgumentError, /fantasma/)
  end

  context "when the announcement has no CTA" do
    let(:announcement) do
      Announcement.new(
        { "slug" => "prueba-diciembre", "subject" => "Aviso", "audience" => "all" },
        "Solo texto, {{first_name}}."
      )
    end

    it "renders without a button" do
      expect(mail.html_part.body.decoded).not_to match(/<a[^>]+class="email-button"/)
    end
  end
end
