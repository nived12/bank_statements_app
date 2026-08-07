# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in_user(user)
    allow_any_instance_of(ApplicationController)
      .to receive(:handle_internal_server_error)
      .and_wrap_original { |_m, exc| raise exc }
  end

  describe "POST /subscription/checkout" do
    let(:checkout_session) { instance_double(Stripe::Checkout::Session, url: "https://checkout.stripe.test/c/sess_1") }
    let(:processor) { instance_double(Pay::Stripe::Customer, checkout: checkout_session) }

    before do
      allow(User).to receive(:stripe_premium_monthly_price_id).and_return("price_monthly_test")
      allow(User).to receive(:stripe_premium_annual_price_id).and_return("price_annual_test")
      allow_any_instance_of(User).to receive(:payment_processor).and_return(processor)
    end

    # Stripe only substitutes a real session id where the *literal* placeholder
    # appears in the success_url string. Without it the return-trip sync has no
    # id to work with and silently no-ops, leaving the webhook as the only path
    # from payment to access.
    it "puts the literal CHECKOUT_SESSION_ID placeholder in the success_url" do
      post "/subscription/checkout", params: { interval: "month" }

      expect(processor).to have_received(:checkout) do |args|
        expect(args[:success_url]).to include("{CHECKOUT_SESSION_ID}")
      end
    end

    # Rails percent-encodes braces passed through url helpers, and Stripe will not
    # match %7BCHECKOUT_SESSION_ID%7D. The placeholder has to survive verbatim.
    it "does not percent-encode the placeholder braces" do
      post "/subscription/checkout", params: { interval: "month" }

      expect(processor).to have_received(:checkout) do |args|
        expect(args[:success_url]).not_to include("%7B")
      end
    end
  end

  describe "GET /subscription with a completed checkout session" do
    let(:stripe_session) { instance_double(Stripe::Checkout::Session, subscription: "sub_test_123") }

    it "syncs the subscription from the returned session id" do
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_123").and_return(stripe_session)
      allow(Pay::Stripe::Subscription).to receive(:sync)

      get "/subscription", params: { success: "1", stripe_checkout_session_id: "cs_test_123" }

      expect(Pay::Stripe::Subscription).to have_received(:sync).with("sub_test_123")
      expect(response).to redirect_to(dashboard_path)
    end

    it "does not attempt a sync when no session id came back" do
      allow(Pay::Stripe::Subscription).to receive(:sync)

      get "/subscription", params: { success: "1" }

      expect(Pay::Stripe::Subscription).not_to have_received(:sync)
      expect(response).to redirect_to(dashboard_path)
    end

    it "still redirects when Stripe raises" do
      allow(Stripe::Checkout::Session)
        .to receive(:retrieve).with("cs_test_123").and_raise(Stripe::StripeError.new("boom"))

      get "/subscription", params: { success: "1", stripe_checkout_session_id: "cs_test_123" }

      expect(response).to redirect_to(dashboard_path)
    end
  end

  describe "GET /subscription billing dates" do
    let(:customer) { create(:pay_customer, owner: user) }

    before { user.update_columns(trial_ends_at: nil) }

    # ends_at is populated only for *cancelled* subscriptions — Pay defines
    # canceled? as literally ends_at?. Reading it as the next billing date meant
    # the renewal line rendered only when there would never be another charge.
    # TimezoneConcern renders the request in the user's zone (falling back to
    # America/Mexico_City), so the request timezone is pinned to UTC to match the
    # spec's own Time.zone. Midday keeps the assertion clear of date boundaries.
    let(:period_end) { Time.utc(2027, 5, 19, 12, 0) }
    let(:formatted) { I18n.l(period_end, format: :long) }

    it "shows the next billing date from current_period_end for a renewing subscription" do
      create(
        :pay_subscription, customer: customer, status: "active",
        current_period_end: period_end, ends_at: nil
      )

      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include(
        I18n.t("subscription.membership.next_billing", date: formatted)
      )
    end

    it "shows a cancellation notice instead of a renewal for a cancelled subscription" do
      create(
        :pay_subscription, customer: customer, status: "active",
        current_period_end: period_end, ends_at: period_end
      )

      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include(
        I18n.t("subscription.membership.cancels_on", date: formatted)
      )
      expect(response.body).not_to include(I18n.t("subscription.membership.next_billing", date: formatted))
    end
  end

  describe "GET /subscription membership card plan and amount" do
    let(:customer) { create(:pay_customer, owner: user) }

    before { user.update_columns(trial_ends_at: nil) }

    # The amount was a hardcoded i18n string of the *current* list price, so an
    # existing subscriber on a retired price was quoted a number they do not pay.
    it "shows what the subscriber is actually billed, not the current list price" do
      create(
        :pay_subscription, :stripe_annual, customer: customer, status: "active",
        processor_plan: "price_retired_1188",
        object: { "items" => { "data" => [ { "price" => {
          "unit_amount" => 118_800, "currency" => "mxn", "recurring" => { "interval" => "year" }
        } } ] } }
      )

      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include(I18n.t("subscription.membership.plan_annual"))
      expect(response.body).to include("MX$1,188.00")
      expect(response.body).not_to include("MX$899.00")
    end

    it "omits plan and amount entirely for a manually granted subscription" do
      # Comp accounts have no Stripe price. Rendering a list price would invent a bill.
      create(:pay_subscription, customer: customer, status: "active")

      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include(I18n.t("subscription.membership.badge"))
      expect(response.body).not_to include(I18n.t("subscription.membership.plan_annual"))
      expect(response.body).not_to include(I18n.t("subscription.membership.plan_monthly"))
      expect(response.body).not_to match(/MX\$[\d,]+\.\d\d\s*\/\s*(mes|año|mo|yr)/)
    end
  end

  describe "GET /subscription when billed by Apple" do
    before do
      user.update_columns(trial_ends_at: nil)
      create(:apple_premium_subscription, user: user)
    end

    # An App Store subscriber has no Pay row, so the page keyed on one would have
    # offered to sell them Premium they already pay for.
    it "shows the membership card, not the upgrade page" do
      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include(I18n.t("subscription.membership.badge"))
      expect(response.body).not_to include(I18n.t("subscription.upgrade.title"))
    end

    # The website is not governed by Apple's anti-steering rules, so naming Apple
    # and linking out is correct here. The iOS app must not do this.
    it "points at Apple instead of the Stripe billing portal" do
      get "/subscription", params: { timezone: "UTC" }

      expect(response.body).to include("apps.apple.com/account/subscriptions")
      expect(response.body).not_to include(portal_subscription_path)
    end

    it "redirects the billing portal back rather than creating a Stripe customer" do
      expect_any_instance_of(User).not_to receive(:set_payment_processor)

      get "/subscription/portal"

      expect(response).to redirect_to(subscription_path)
    end
  end
end
