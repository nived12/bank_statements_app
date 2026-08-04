# frozen_string_literal: true

require "rails_helper"

# The landing page Stripe returns the mobile in-app browser to after checkout.
# Public: the in-app browser does not carry the session cookie.
RSpec.describe "Checkout", type: :request do
  describe "GET /checkout/success" do
    let(:stripe_session) { instance_double(Stripe::Checkout::Session, subscription: "sub_test_123") }

    it "syncs the subscription from the returned session id" do
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_123").and_return(stripe_session)
      allow(Pay::Stripe::Subscription).to receive(:sync)

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      expect(response).to have_http_status(:success)
      expect(Pay::Stripe::Subscription).to have_received(:sync).with("sub_test_123")
    end

    it "renders without syncing when no session id came back" do
      allow(Pay::Stripe::Subscription).to receive(:sync)

      get "/checkout/success"

      expect(response).to have_http_status(:success)
      expect(Pay::Stripe::Subscription).not_to have_received(:sync)
    end

    # The user has already paid at this point — a failure here must not turn the
    # confirmation page into an error. The webhook remains the backstop.
    it "still renders the confirmation when Stripe raises" do
      allow(Stripe::Checkout::Session)
        .to receive(:retrieve).with("cs_test_123").and_raise(Stripe::StripeError.new("boom"))

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      expect(response).to have_http_status(:success)
    end

    # Pay wraps Stripe errors in its own class hierarchy, and the sync writes to
    # the DB — neither surfaces as a Stripe::StripeError.
    it "still renders the confirmation when Pay raises" do
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_123").and_return(stripe_session)
      allow(Pay::Stripe::Subscription).to receive(:sync).and_raise(Pay::Error.new("nope"))

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      expect(response).to have_http_status(:success)
    end

    it "still renders the confirmation when the sync fails to write" do
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_123").and_return(stripe_session)
      allow(Pay::Stripe::Subscription)
        .to receive(:sync).and_raise(ActiveRecord::RecordInvalid.new(Pay::Subscription.new))

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      expect(response).to have_http_status(:success)
    end

    it "renders without syncing when the session has no subscription" do
      allow(Stripe::Checkout::Session)
        .to receive(:retrieve).with("cs_test_123")
        .and_return(instance_double(Stripe::Checkout::Session, subscription: nil))
      allow(Pay::Stripe::Subscription).to receive(:sync)

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      expect(response).to have_http_status(:success)
      expect(Pay::Stripe::Subscription).not_to have_received(:sync)
    end
  end
end
