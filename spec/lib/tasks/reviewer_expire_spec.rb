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

  # and_call_original first, then narrow — per the ENV-stubbing rule in CLAUDE.md,
  # without which load order decides whether unrelated ENV reads survive.
  def with_demo_password(password)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DEMO_PASSWORD").and_return(password)
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

  describe "creating the account" do
    let(:email) { "demo-expired@vitt.io" }

    it "creates a usable, already-expired account when given a password" do
      with_demo_password("reviewer-demo-123")

      run(email)

      created = User.find_by(email: email)
      expect(created.authenticate("reviewer-demo-123")).to be_truthy
      expect(created.active_trial?).to be false
      expect(created.active_paid_subscription?).to be false
      # create_default_data — without it reviewer:seed has no categories to match.
      expect(created.categories).to be_present
    end

    it "aborts without a password rather than creating an account nobody can sign into" do
      expect { run(email) }.to raise_error(SystemExit)
      expect(User.find_by(email: email)).to be_nil
    end

    it "resets a forgotten password on an existing account" do
      user
      with_demo_password("brand-new-pw-456")

      run(user.email)

      expect(user.reload.authenticate("brand-new-pw-456")).to be_truthy
    end

    it "leaves the password alone when DEMO_PASSWORD is absent" do
      user.update!(password: "original-pw-789", password_confirmation: "original-pw-789")

      run(user.email)

      expect(user.reload.authenticate("original-pw-789")).to be_truthy
    end
  end

  it "refuses to touch a non-demo account in production" do
    victim = create(:user, email: "paying-customer@example.com")
    create(:apple_premium_subscription, user: victim)
    allow(Rails.env).to receive(:production?).and_return(true)

    expect { run(victim.email) }.to raise_error(SystemExit)
    expect(victim.reload.apple_premium_subscription).to be_present
  end

  it "refuses to create a non-demo account in production" do
    allow(Rails.env).to receive(:production?).and_return(true)
    with_demo_password("reviewer-demo-123")

    expect { run("attacker@example.com") }.to raise_error(SystemExit)
    expect(User.find_by(email: "attacker@example.com")).to be_nil
  end
end
