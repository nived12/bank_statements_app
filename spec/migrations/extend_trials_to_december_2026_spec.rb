require "rails_helper"
require Rails.root.join("db/migrate/20260907120200_extend_trials_to_december_2026")

RSpec.describe ExtendTrialsToDecember2026 do
  let(:target) { described_class::TARGET }

  def user_with_trial(days_from_now, stage: nil, **attrs)
    create(:user, **attrs).tap do |u|
      u.update_columns(trial_ends_at: days_from_now.days.from_now, trial_reminder_stage: stage)
    end
  end

  def migrate!
    described_class.new.up
  end

  it "moves an expiring trial to the target date" do
    user = user_with_trial(5)

    migrate!

    expect(user.reload.trial_ends_at.to_date).to eq(target.to_date)
  end

  it "moves an already-expired trial to the target date" do
    user = user_with_trial(-40)

    migrate!

    expect(user.reload.trial_ends_at.to_date).to eq(target.to_date)
  end

  # The whole reason this lives in a migration rather than a console command:
  # trial_reminder_stage only ever decreases, so a user left at stage 1 would
  # never receive another trial reminder before the new date.
  it "clears trial_reminder_stage so the reminders fire again in December" do
    user = user_with_trial(-2, stage: 1)

    migrate!

    expect(user.reload.trial_reminder_stage).to be_nil
  end

  it "leaves internal accounts expired so store review still sees the paywall" do
    fixture = user_with_trial(-30, internal_account: true)

    migrate!

    expect(fixture.reload.trial_ends_at.to_date).not_to eq(target.to_date)
  end

  it "skips users who are already paying" do
    payer = user_with_trial(5)
    allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(false)
    allow_any_instance_of(User).to receive(:active_paid_subscription?).with(no_args) do |user|
      user.id == payer.id
    end

    migrate!

    expect(payer.reload.trial_ends_at.to_date).not_to eq(target.to_date)
  end

  it "skips unconfirmed and discarded users" do
    unconfirmed = user_with_trial(5, confirmed_at: nil)
    discarded = user_with_trial(5).tap(&:discard)

    migrate!

    expect(unconfirmed.reload.trial_ends_at.to_date).not_to eq(target.to_date)
    expect(discarded.reload.trial_ends_at.to_date).not_to eq(target.to_date)
  end
end
