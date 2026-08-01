# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
  end

  describe "GET /api/v1/subscription" do
    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/subscription"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is on active trial" do
      before { user.update_columns(trial_ends_at: 7.days.from_now) }

      it "returns trialing status" do
        get "/api/v1/subscription", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]

        expect(data["plan"]).to be_nil
        expect(data["status"]).to eq("trialing")
        expect(data["billing_interval"]).to be_nil
        expect(data["trial_ends_at"]).to be_present
        expect(data["current_period_end"]).to be_nil
        expect(data["cancel_at_period_end"]).to eq(false)
      end
    end

    context "when user has an active premium subscription" do
      before do
        user.update_columns(trial_ends_at: nil)
        customer = create(:pay_customer, owner: user)
        create(:pay_subscription, customer: customer, status: "active")
      end

      it "returns active status with premium plan" do
        get "/api/v1/subscription", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]

        expect(data["plan"]).to eq("premium")
        expect(data["status"]).to eq("active")
        expect(data["billing_interval"]).to eq("month")
        expect(data["cancel_at_period_end"]).to eq(false)
      end
    end

    context "when annual subscription and price id matches" do
      before do
        annual_price_id = "price_annual_test_123"
        allow(User).to receive(:stripe_premium_annual_price_id).and_return(annual_price_id)
        user.update_columns(trial_ends_at: nil)
        customer = create(:pay_customer, owner: user)
        create(:pay_subscription, customer: customer, status: "active", processor_plan: annual_price_id)
      end

      it "returns year billing_interval" do
        get "/api/v1/subscription", headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["data"]["billing_interval"]).to eq("year")
      end
    end

    context "when trial has expired and no subscription" do
      before { user.update_columns(trial_ends_at: 1.day.ago) }

      it "returns null plan and status" do
        get "/api/v1/subscription", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]

        expect(data["plan"]).to be_nil
        expect(data["status"]).to be_nil
        expect(data["billing_interval"]).to be_nil
        expect(data["trial_ends_at"]).to be_nil
        expect(data["current_period_end"]).to be_nil
        expect(data["cancel_at_period_end"]).to eq(false)
      end
    end
  end

  describe "POST /api/v1/subscription/checkout" do
    context "when unauthenticated" do
      it "returns 401" do
        post "/api/v1/subscription/checkout", params: { interval: "month" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid interval" do
      it "returns 422 INVALID_INTERVAL" do
        post "/api/v1/subscription/checkout",
          params: { interval: "weekly" },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("INVALID_INTERVAL")
      end
    end

    context "when price env vars are not configured" do
      before do
        allow(User).to receive(:stripe_premium_monthly_price_id).and_return(nil)
        allow(User).to receive(:stripe_premium_annual_price_id).and_return(nil)
      end

      it "returns 503 SERVICE_UNAVAILABLE for month interval" do
        post "/api/v1/subscription/checkout",
          params: { interval: "month" },
          headers: auth_headers

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("SERVICE_UNAVAILABLE")
      end

      it "returns 503 SERVICE_UNAVAILABLE for year interval" do
        post "/api/v1/subscription/checkout",
          params: { interval: "year" },
          headers: auth_headers

        expect(response).to have_http_status(:service_unavailable)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("SERVICE_UNAVAILABLE")
      end
    end

    # Switching plans mid-cycle. "create_prorations" only writes line items onto
    # the *upcoming* invoice, which for an annual plan is a year out — the user
    # gets a year of Premium billed nothing now and a stacked bill later. Upgrades
    # must invoice the prorated difference immediately.
    context "when the user already has a paid subscription on a different plan" do
      # instance_double of the STI subclass, not the base class: #swap is defined
      # on Pay::Stripe::Subscription, which is what production rows actually are.
      # The :pay_subscription factory leaves type nil and so has no #swap.
      let(:active_sub) do
        instance_double(Pay::Stripe::Subscription, processor_plan: "price_monthly_test", swap: true)
      end

      before do
        allow(User).to receive(:stripe_premium_monthly_price_id).and_return("price_monthly_test")
        allow(User).to receive(:stripe_premium_annual_price_id).and_return("price_annual_test")
        allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(true)
        allow_any_instance_of(User).to receive(:current_paid_subscription).and_return(active_sub)
      end

      it "invoices the proration immediately instead of deferring it" do
        post "/api/v1/subscription/checkout", params: { interval: "year" }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["data"]["switched"]).to be true
        expect(active_sub).to have_received(:swap)
          .with("price_annual_test", proration_behavior: "always_invoice")
      end

      it "invoices the proration immediately when downgrading too" do
        allow(active_sub).to receive(:processor_plan).and_return("price_annual_test")

        post "/api/v1/subscription/checkout", params: { interval: "month" }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(active_sub).to have_received(:swap)
          .with("price_monthly_test", proration_behavior: "always_invoice")
      end

      # always_invoice charges at the moment of the switch, so a decline now
      # surfaces here. Pay wraps Stripe errors, so rescuing Stripe::CardError
      # would never fire; and Pay::PaymentError does not descend from Pay::Error.
      [ "Pay::Stripe::Error", "Pay::ActionRequired", "Pay::InvalidPaymentMethod" ].each do |error_class|
        it "returns a payment error, not a 500, when swap raises #{error_class}" do
          klass = error_class.constantize
          failure = klass <= Pay::PaymentError ? klass.new(Pay::Payment.new(nil)) : klass.new("card_declined")
          allow(active_sub).to receive(:swap).and_raise(failure)

          post "/api/v1/subscription/checkout", params: { interval: "year" }, headers: auth_headers

          expect(response).to have_http_status(:payment_required)
          expect(JSON.parse(response.body)["error"]["code"]).to eq("PAYMENT_FAILED")
        end
      end

      it "rejects switching to the plan the user is already on" do
        post "/api/v1/subscription/checkout", params: { interval: "month" }, headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("ALREADY_SUBSCRIBED")
        expect(active_sub).not_to have_received(:swap)
      end
    end

    context "with valid interval and configured price" do
      let(:fake_session) { double("Stripe::Session", url: "https://checkout.stripe.com/test_abc123") }
      let(:fake_processor) { double("Pay::Stripe::Billable") }

      before do
        allow(User).to receive(:stripe_premium_monthly_price_id).and_return("price_monthly_test")
        allow(User).to receive(:stripe_premium_annual_price_id).and_return("price_annual_test")
        allow_any_instance_of(User).to receive(:payment_processor).and_return(fake_processor)
        allow(fake_processor).to receive(:checkout).and_return(fake_session)
      end

      it "returns 200 with checkout_url for month interval" do
        post "/api/v1/subscription/checkout",
          params: {
            interval: "month",
            success_url: "https://app.vitt.io/subscription?success=1",
            cancel_url: "https://app.vitt.io/subscription"
          },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["checkout_url"]).to eq("https://checkout.stripe.com/test_abc123")
      end

      it "returns 200 with checkout_url for year interval" do
        post "/api/v1/subscription/checkout",
          params: {
            interval: "year",
            success_url: "https://app.vitt.io/subscription?success=1",
            cancel_url: "https://app.vitt.io/subscription"
          },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["checkout_url"]).to eq("https://checkout.stripe.com/test_abc123")
      end

      it "calls checkout with the monthly price_id" do
        expect(fake_processor).to receive(:checkout).with(
          hash_including(
            mode: "subscription",
            line_items: [{ price: "price_monthly_test", quantity: 1 }]
          )
        ).and_return(fake_session)

        post "/api/v1/subscription/checkout",
          params: { interval: "month" },
          headers: auth_headers
      end

      it "calls checkout with the annual price_id" do
        expect(fake_processor).to receive(:checkout).with(
          hash_including(
            line_items: [{ price: "price_annual_test", quantity: 1 }]
          )
        ).and_return(fake_session)

        post "/api/v1/subscription/checkout",
          params: { interval: "year" },
          headers: auth_headers
      end
    end
  end

  describe "GET /api/v1/subscription/portal" do
    context "when unauthenticated" do
      it "returns 401" do
        get "/api/v1/subscription/portal"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user has no payment method (Pay::Error)" do
      before do
        fake_processor = double("Pay::Stripe::Billable")
        allow_any_instance_of(User).to receive(:payment_processor).and_return(fake_processor)
        allow(fake_processor).to receive(:billing_portal).and_raise(Pay::Error)
      end

      it "returns 422 NO_PAYMENT_METHOD" do
        get "/api/v1/subscription/portal", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("NO_PAYMENT_METHOD")
      end
    end

    context "when billing portal is available" do
      let(:fake_session) { double("Stripe::BillingPortal::Session", url: "https://billing.stripe.com/test_portal") }
      let(:fake_processor) { double("Pay::Stripe::Billable") }

      before do
        allow_any_instance_of(User).to receive(:payment_processor).and_return(fake_processor)
        allow(fake_processor).to receive(:billing_portal).and_return(fake_session)
      end

      it "returns 200 with portal_url" do
        get "/api/v1/subscription/portal", headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["portal_url"]).to eq("https://billing.stripe.com/test_portal")
      end

      it "ignores client-supplied return_url and uses APP_URL instead" do
        expect(fake_processor).to receive(:billing_portal).with(
          return_url: ENV.fetch("APP_URL", "https://app.vitt.io")
        ).and_return(fake_session)

        get "/api/v1/subscription/portal",
          params: { return_url: "https://evil.com" },
          headers: auth_headers
      end
    end
  end
end
