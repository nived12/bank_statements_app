# frozen_string_literal: true

require "rails_helper"
require "rake"

# reviewer:expire is the only thing standing between us and a repeat of the
# Guideline 2.1 rejection on 1.0(7): App Review needs an account whose trial has
# run out so the IAP purchase flow is reachable. The reviewer then *buys* with
# that account, which flips it to premium — so this has to work every time it is
# re-run before a resubmission, not just the first time.
RSpec.describe "reviewer:expire", type: :task do
  before(:all) do
    Rake::Task.clear
    Rails.application.load_tasks
  end

  before { Rake::Task["reviewer:expire"].reenable }

  # Rake writes its report to stdout; capture it so the suite output stays clean
  # and so examples can assert on what the operator is told.
  def run(email)
    capture_stdout { Rake::Task["reviewer:expire"].invoke(email) }
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  let(:user) { create(:user, email: "demo-expired@vitt.io", trial_ends_at: 10.days.from_now) }

  it "expires the trial so the paywall is reachable" do
    expect(user.active_trial?).to be true

    run(user.email)

    expect(user.reload.active_trial?).to be false
  end

  it "revokes an App Store entitlement left over from the reviewer's own sandbox purchase" do
    create(:apple_premium_subscription, user: user)
    expect(user.reload.active_paid_subscription?).to be true

    run(user.email)

    expect(user.reload.apple_premium_subscription).to be_nil
    expect(user.active_paid_subscription?).to be false
    expect(user.billing_source).to be_nil
  end

  it "revokes a Stripe subscription too, so neither source can grant access" do
    create(:pay_subscription, customer: create(:pay_customer, owner: user))

    run(user.email)

    expect(user.reload.pay_subscriptions).to be_empty
    expect(user.active_paid_subscription?).to be false
  end

  it "warns when it removed a real Stripe row, which the webhook would restore" do
    create(:pay_subscription, :stripe_monthly, customer: create(:pay_customer, owner: user))

    expect(run(user.email)).to match(/Cancel them in the Stripe dashboard/)
  end

  it "stays quiet about Stripe when the row was only a comp grant" do
    create(:pay_subscription, customer: create(:pay_customer, owner: user))

    expect(run(user.email)).not_to match(/Stripe dashboard/)
  end

  it "confirms and consents the account, which otherwise block the API before the paywall" do
    user.update!(
      confirmed_at: nil, legal_version_accepted: nil,
      terms_accepted_at: nil, privacy_accepted_at: nil
    )

    run(user.email)

    expect(user.reload.confirmed_at).to be_present
    expect(user.legal_consent_current?).to be true
  end

  it "aborts rather than inventing an account, so no demo password lands in the repo" do
    expect { run("nobody@vitt.io") }.to raise_error(SystemExit)
    expect(User.find_by(email: "nobody@vitt.io")).to be_nil
  end

  it "refuses to strip billing from a non-demo account in production" do
    victim = create(:user, email: "paying-customer@example.com")
    create(:apple_premium_subscription, user: victim)
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { run(victim.email) }.to raise_error(SystemExit)
    expect(victim.reload.apple_premium_subscription).to be_present
  end
end
