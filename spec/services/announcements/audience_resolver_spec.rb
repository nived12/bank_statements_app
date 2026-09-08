require "rails_helper"

RSpec.describe Announcements::AudienceResolver do
  def resolve(filters = {})
    described_class.call(filters).payload
  end

  def user_with_trial_on(date, **attrs)
    create(:user, **attrs).tap { |u| u.update_columns(trial_ends_at: date.end_of_day) }
  end

  describe "base eligibility, applied to every campaign" do
    it "includes a confirmed, kept, opted-in user" do
      user = create(:user)

      expect(resolve).to eq([user])
    end

    it "excludes internal accounts" do
      create(:user, internal_account: true)

      expect(resolve).to be_empty
    end

    it "excludes users who opted out of announcements" do
      create(:user).user_setting.update!(notify_announcements: false)

      expect(resolve).to be_empty
    end

    it "excludes unconfirmed and discarded users" do
      create(:user, confirmed_at: nil)
      create(:user).discard

      expect(resolve).to be_empty
    end

    # A feature announcement is exactly for paying users, so they are only
    # excluded when a campaign asks for it.
    it "includes paying users by default" do
      payer = create(:user)
      allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(true)

      expect(resolve).to eq([payer])
    end
  end

  describe "filters" do
    it "trial_ends_on matches the date only" do
      match = user_with_trial_on(Date.new(2026, 12, 31))
      user_with_trial_on(Date.new(2026, 11, 30))

      expect(resolve("trial_ends_on" => Date.new(2026, 12, 31))).to eq([match])
    end

    it "has_transactions true keeps only users with transactions" do
      active = create(:user)
      create(:transaction, user: active)
      create(:user)

      expect(resolve("has_transactions" => true)).to eq([active])
    end

    # The :transaction factory builds its own bank_account, statement_file and
    # category, each of which creates a user, so the "no transactions" set has
    # more members than this example creates by hand.
    it "has_transactions false keeps only users with none" do
      with_txns = create(:user)
      create(:transaction, user: with_txns)
      never_started = create(:user)

      result = resolve("has_transactions" => false)

      expect(result).to include(never_started)
      expect(result).not_to include(with_txns)
    end

    it "paying false excludes subscribers" do
      payer = create(:user)
      free = create(:user)
      allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(false)
      allow_any_instance_of(User).to receive(:active_paid_subscription?).with(no_args) do |user|
        user.id == payer.id
      end

      expect(resolve("paying" => false)).to eq([free])
    end

    it "combines filters with AND" do
      wanted = user_with_trial_on(Date.new(2026, 12, 31))
      create(:transaction, user: user_with_trial_on(Date.new(2026, 12, 31)))
      user_with_trial_on(Date.new(2026, 1, 1))

      result = resolve("trial_ends_on" => Date.new(2026, 12, 31), "has_transactions" => false)

      expect(result).to eq([wanted])
    end

    it "accepts symbol keys" do
      user = create(:user)

      expect(resolve(has_transactions: false)).to eq([user])
    end
  end

  # A typo in frontmatter must be loud. Silently ignoring an unknown filter
  # would broadcast to a much wider audience than the campaign intended.
  it "raises on an unknown filter" do
    expect { resolve("has_bank_account" => true) }
      .to raise_error(ArgumentError, /has_bank_account/)
  end

  it "treats a nil audience as everyone eligible" do
    user = create(:user)

    expect(described_class.call(nil).payload).to eq([user])
  end
end
