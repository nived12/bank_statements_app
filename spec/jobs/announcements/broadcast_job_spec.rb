require "rails_helper"

RSpec.describe Announcements::BroadcastJob, type: :job do
  def announcement(slug, audience = {}, body = "Hola {{first_name}}.")
    Announcement.new(
      { "slug" => slug, "subject" => "Aviso", "audience" => audience }, body
    )
  end

  def stub_announcement(slug, audience = {})
    allow(Announcement).to receive(:find).with(slug).and_return(announcement(slug, audience))
  end

  # The job sends inline (see deliver_to), so delivered mail is the signal.
  def delivered_to
    ActionMailer::Base.deliveries.map { |m| m.to.first }
  end

  describe "delivery" do
    before { stub_announcement("aviso") }

    it "mails every eligible user and records the delivery" do
      users = create_list(:user, 2)

      described_class.perform_now("aviso")

      expect(delivered_to.size).to eq(2)
      users.each do |user|
        delivery = AnnouncementDelivery.find_by(user: user, campaign: "aviso")
        expect(delivery.sent_at).to be_present
      end
    end

    it "raises on a slug with no announcement file" do
      allow(Announcement).to receive(:find).with(:missing.to_s).and_return(nil)

      expect { described_class.perform_now("missing") }.to raise_error(ArgumentError, /missing/)
    end
  end

  describe "idempotency" do
    before { stub_announcement("aviso") }

    it "sends nothing on a second run" do
      create(:user)

      described_class.perform_now("aviso")
      ActionMailer::Base.deliveries.clear
      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    # The unique index is the real guard; this proves the job defers to it
    # rather than to its own read-then-write check.
    it "skips a user already recorded by another worker" do
      user = create(:user)
      AnnouncementDelivery.create!(user: user, campaign: "aviso", sent_at: Time.current)

      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    it "leaves sent_at nil when the mail fails, so the row is a retry marker" do
      create(:user)
      allow(AnnouncementMailer).to receive(:broadcast).and_raise(StandardError, "smtp down")

      described_class.perform_now("aviso")

      expect(AnnouncementDelivery.count).to eq(1)
      expect(AnnouncementDelivery.first.sent_at).to be_nil
    end

    it "retries a user whose earlier run left sent_at nil" do
      user = create(:user)
      AnnouncementDelivery.create!(user: user, campaign: "aviso")

      described_class.perform_now("aviso")

      expect(delivered_to).to eq([user.email])
      expect(AnnouncementDelivery.count).to eq(1)
      expect(AnnouncementDelivery.first.sent_at).to be_present
    end

    # The round trip the class comment promises: a failed send is picked up by
    # the next run, exactly once.
    it "picks the user up on a re-run after the first send failed" do
      user = create(:user)
      allow(AnnouncementMailer).to receive(:broadcast).and_raise(StandardError, "smtp down")
      described_class.perform_now("aviso")

      allow(AnnouncementMailer).to receive(:broadcast).and_call_original
      described_class.perform_now("aviso")

      expect(delivered_to).to eq([user.email])
      expect(AnnouncementDelivery.count).to eq(1)
      expect(AnnouncementDelivery.first.sent_at).to be_present
    end
  end

  describe "eligibility" do
    before { stub_announcement("aviso") }

    it "skips internal accounts" do
      create(:user, internal_account: true)

      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    it "skips users who opted out of announcements" do
      user = create(:user)
      user.user_setting.update!(notify_announcements: false)

      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    it "skips unconfirmed users" do
      create(:user, confirmed_at: nil)

      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    it "skips discarded users" do
      create(:user).discard

      described_class.perform_now("aviso")

      expect(delivered_to).to be_empty
    end

    it "keeps going when one user raises" do
      good = create(:user)
      bad = create(:user)
      allow(AnnouncementMailer).to receive(:broadcast).and_call_original
      allow(AnnouncementMailer).to receive(:broadcast).with(bad, anything).and_raise("boom")

      described_class.perform_now("aviso")

      expect(AnnouncementDelivery.find_by(user: good).sent_at).to be_present
    end
  end

  describe "audience" do
    it "delegates to the resolver with the announcement's declared filters" do
      stub_announcement("aviso", "has_transactions" => false)
      allow(Announcements::AudienceResolver).to receive(:call).and_call_original

      described_class.perform_now("aviso")

      expect(Announcements::AudienceResolver)
        .to have_received(:call).with("has_transactions" => false)
    end
  end
end
