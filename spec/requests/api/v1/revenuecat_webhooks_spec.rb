# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::RevenuecatWebhooks", type: :request do
  let(:user) { create(:user) }
  let(:secret) { "test-revenuecat-secret" }
  let(:auth_headers) { { "Authorization" => secret } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("REVENUECAT_WEBHOOK_AUTH_HEADER").and_return(secret)
  end

  def event_payload(type: "INITIAL_PURCHASE", **overrides)
    {
      api_version: "1.0",
      event: {
        type: type,
        app_user_id: user.id.to_s,
        product_id: "io.vitt.app.premium.monthly",
        expiration_at_ms: 30.days.from_now.to_i * 1000,
        price_in_purchased_currency: 99.0,
        currency: "MXN",
        original_transaction_id: "1000000123456789",
        store: "APP_STORE",
        environment: "PRODUCTION"
      }.merge(overrides)
    }
  end

  def post_event(payload, headers: auth_headers)
    post "/api/v1/revenuecat/webhook", params: payload, as: :json, headers: headers
  end

  describe "authentication" do
    it "rejects a request with no Authorization header" do
      post_event(event_payload, headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(user.reload.apple_premium_subscription).to be_nil
    end

    it "rejects a request with the wrong secret" do
      post_event(event_payload, headers: { "Authorization" => "wrong" })

      expect(response).to have_http_status(:unauthorized)
      expect(user.reload.apple_premium_subscription).to be_nil
    end

    # Without this the endpoint would accept anything the moment the env var went
    # missing in production — an unauthenticated write to entitlements.
    it "rejects every request when the secret is not configured" do
      allow(ENV).to receive(:[]).with("REVENUECAT_WEBHOOK_AUTH_HEADER").and_return(nil)

      post_event(event_payload, headers: { "Authorization" => "" })

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "granting entitlement" do
    it "creates the entitlement on INITIAL_PURCHASE" do
      post_event(event_payload)

      expect(response).to have_http_status(:ok)
      entitlement = user.reload.apple_premium_subscription
      expect(entitlement).to be_present
      expect(entitlement).to be_active
      expect(entitlement.billing_interval).to eq(:month)
      expect(entitlement.billing_amount_cents).to eq(9_900)
      expect(entitlement.billing_currency).to eq("MXN")
      expect(entitlement.original_transaction_id).to eq("1000000123456789")
      expect(entitlement.auto_renews).to be true
    end

    it "unlocks premium for a user whose trial has expired" do
      user.update_columns(trial_ends_at: 1.day.ago)

      post_event(event_payload)

      expect(user.reload.active_paid_subscription?).to be true
      expect(user.billing_source).to eq("apple")
    end

    it "records an annual purchase at its own price and interval" do
      post_event(
        event_payload(
          product_id: "io.vitt.app.premium.annual",
          price_in_purchased_currency: 899.0,
          expiration_at_ms: 1.year.from_now.to_i * 1000
        )
      )

      entitlement = user.reload.apple_premium_subscription
      expect(entitlement.billing_interval).to eq(:year)
      expect(entitlement.billing_amount_cents).to eq(89_900)
    end

    it "extends the same row on RENEWAL rather than creating a second one" do
      post_event(event_payload)
      original_id = user.reload.apple_premium_subscription.id

      post_event(event_payload(type: "RENEWAL", expiration_at_ms: 60.days.from_now.to_i * 1000))

      expect(user.reload.apple_premium_subscription.id).to eq(original_id)
      expect(ApplePremiumSubscription.where(user_id: user.id).count).to eq(1)
      expect(user.apple_premium_subscription.expires_at).to be > 45.days.from_now
    end

    # Apple's reviewers test with a Sandbox account. Rejecting sandbox events would
    # mean their purchase never unlocks anything — a Guideline 2.1 rejection.
    it "honours a SANDBOX purchase" do
      post_event(event_payload(environment: "SANDBOX"))

      expect(response).to have_http_status(:ok)
      expect(user.reload.apple_premium_subscription).to be_active
    end
  end

  describe "ending entitlement" do
    before { post_event(event_payload) }

    it "marks auto-renew off on CANCELLATION but keeps access until expiry" do
      post_event(event_payload(type: "CANCELLATION"))

      entitlement = user.reload.apple_premium_subscription
      expect(entitlement.auto_renews).to be false
      expect(entitlement).to be_active
      expect(user.active_paid_subscription?).to be true
    end

    it "revokes access on EXPIRATION" do
      post_event(event_payload(type: "EXPIRATION", expiration_at_ms: 1.hour.ago.to_i * 1000))

      expect(user.reload.apple_premium_subscription).not_to be_active
      expect(user.active_paid_subscription?).to be false
    end

    it "keeps access during a BILLING_ISSUE grace period" do
      post_event(event_payload(type: "BILLING_ISSUE"))

      expect(user.reload.active_paid_subscription?).to be true
    end

    it "switches interval on PRODUCT_CHANGE" do
      post_event(
        event_payload(
          type: "PRODUCT_CHANGE",
          product_id: "io.vitt.app.premium.annual",
          price_in_purchased_currency: 899.0,
          expiration_at_ms: 1.year.from_now.to_i * 1000
        )
      )

      expect(user.reload.apple_premium_subscription.billing_interval).to eq(:year)
    end
  end

  describe "idempotency" do
    # RevenueCat retries on any non-2xx, so the same event can arrive repeatedly.
    it "reaches the same state when the same event is delivered twice" do
      payload = event_payload
      post_event(payload)
      first = user.reload.apple_premium_subscription.attributes.except("updated_at")

      post_event(payload)
      second = user.reload.apple_premium_subscription.attributes.except("updated_at")

      expect(second).to eq(first)
      expect(ApplePremiumSubscription.where(user_id: user.id).count).to eq(1)
    end
  end

  describe "payloads that must not 500" do
    # A 500 makes RevenueCat retry forever. These are permanent conditions, so they
    # must be acknowledged instead.
    it "acknowledges an event for a user who no longer exists" do
      post_event(event_payload(app_user_id: "999999999"))

      expect(response).to have_http_status(:ok)
    end

    it "acknowledges an unrecognised event type without touching the entitlement" do
      post_event(event_payload(type: "TRANSFER"))

      expect(response).to have_http_status(:ok)
      expect(user.reload.apple_premium_subscription).to be_nil
    end

    it "ignores a non-App Store purchase" do
      post_event(event_payload(store: "PLAY_STORE"))

      expect(response).to have_http_status(:ok)
      expect(user.reload.apple_premium_subscription).to be_nil
    end

    it "records an unknown product without inventing an interval" do
      post_event(event_payload(product_id: "io.vitt.app.premium.weekly"))

      entitlement = user.reload.apple_premium_subscription
      expect(entitlement).to be_active
      expect(entitlement.billing_interval).to be_nil
    end

    it "acknowledges an event with no expiry rather than crashing" do
      post_event(event_payload(expiration_at_ms: nil))

      expect(response).to have_http_status(:ok)
      expect(user.reload.apple_premium_subscription).to be_nil
    end
  end
end
