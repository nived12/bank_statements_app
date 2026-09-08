require "rails_helper"

RSpec.describe Announcements::BroadcastJob, type: :job do
  let(:target) { Announcements::BroadcastJob::TRIAL_EXTENSION_DATE.end_of_day }

  # trial_ends_at is stamped by a SubscriptionAccess after_create hook, so it
  # has to be overwritten once the record exists.
  def extended_user(**attrs)
    create(:user, **attrs).tap { |u| u.update_columns(trial_ends_at: target) }
  end

  def with_transaction(user)
    create(:transaction, user: user)
    user
  end

  def announcement(slug, audience, body = "Hola {{first_name}}.")
    Announcement.new(
      { "slug" => slug, "subject" => "Aviso", "audience" => audience }, body
    )
  end

  def stub_announcement(slug, audience)
    allow(Announcement).to receive(:find).with(slug).and_return(announcement(slug, audience))
  end

  def enqueued_broadcasts
    ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:args].first == "AnnouncementMailer" && job[:args].second == "broadcast"
    end
  end

  describe "delivery" do
    before { stub_announcement("aviso", "all") }

    it "mails every eligible user and records the delivery" do
      users = create_list(:user, 2)

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts.size).to eq(2)
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
    before { stub_announcement("aviso", "all") }

    it "sends nothing on a second run" do
      create(:user)

      described_class.perform_now("aviso")
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
    end

    # The unique index is the real guard; this proves the job defers to it
    # rather than to its own read-then-write check.
    it "skips a user already recorded by another worker" do
      user = create(:user)
      AnnouncementDelivery.create!(user: user, campaign: "aviso", sent_at: Time.current)

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
    end

    it "leaves sent_at nil when the mail fails, so the row is a retry marker" do
      create(:user)
      allow(AnnouncementMailer).to receive(:broadcast).and_raise(StandardError, "smtp down")

      described_class.perform_now("aviso")

      expect(AnnouncementDelivery.count).to eq(1)
      expect(AnnouncementDelivery.first.sent_at).to be_nil
    end
  end

  describe "eligibility" do
    before { stub_announcement("aviso", "all") }

    it "skips internal accounts" do
      create(:user, internal_account: true)

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
    end

    it "skips users who opted out of announcements" do
      user = create(:user)
      user.user_setting.update!(notify_announcements: false)

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
    end

    it "skips unconfirmed users" do
      create(:user, confirmed_at: nil)

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
    end

    it "skips discarded users" do
      create(:user).discard

      described_class.perform_now("aviso")

      expect(enqueued_broadcasts).to be_empty
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

  describe "the trial extension audiences" do
    it "sends the active copy only to users with transactions" do
      stub_announcement("activos", "trial_extended_2026_12_active")
      active = with_transaction(extended_user)
      extended_user # never onboarded

      described_class.perform_now("activos")

      expect(AnnouncementDelivery.pluck(:user_id)).to eq([active.id])
    end

    it "sends the onboarding copy only to users with no transactions" do
      stub_announcement("onboarding", "trial_extended_2026_12_onboarding")
      with_transaction(extended_user)
      never_started = extended_user

      described_class.perform_now("onboarding")

      expect(AnnouncementDelivery.pluck(:user_id)).to eq([never_started.id])
    end

    # A user who subscribes between the migration and the send should not be
    # told their trial was extended.
    it "skips someone who started paying after the extension" do
      stub_announcement("onboarding", "trial_extended_2026_12_onboarding")
      payer = extended_user
      allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(false)
      allow_any_instance_of(User).to receive(:active_paid_subscription?).with(no_args) do |user|
        user.id == payer.id
      end

      described_class.perform_now("onboarding")

      expect(AnnouncementDelivery.where(user_id: payer.id)).to be_empty
    end

    it "ignores users whose trial was never extended" do
      stub_announcement("onboarding", "trial_extended_2026_12_onboarding")
      create(:user).update_columns(trial_ends_at: 5.days.from_now)

      described_class.perform_now("onboarding")

      expect(enqueued_broadcasts).to be_empty
    end
  end
end
