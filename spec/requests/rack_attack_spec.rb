require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  let(:limit) { 3 }

  describe "email confirmation rate limiting" do
    it "allows requests under the limit" do
      limit.times do
        post email_confirmations_path, params: { email: "test@example.com" }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).not_to match(/rate limit/i)
      end
    end

    it "blocks requests over the limit and shows error message" do
      # Make requests up to the limit
      limit.times do
        post email_confirmations_path, params: { email: "test@example.com" }
      end

      # Next request should be rate limited
      post email_confirmations_path, params: { email: "test@example.com" }

      expect(response).to have_http_status(:redirect)
      # Check flash immediately after the response, before following redirect
      expect(flash[:alert]).to match(/Límite de solicitudes excedido/)
    end
  end

  describe "password reset rate limiting" do
    it "allows requests under the limit" do
      limit.times do
        post password_resets_path, params: { email: "test@example.com" }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).not_to match(/rate limit/i)
      end
    end

    it "blocks requests over the limit and shows error message" do
      # Make requests up to the limit
      limit.times do
        post password_resets_path, params: { email: "test@example.com" }
      end

      # Next request should be rate limited
      post password_resets_path, params: { email: "test@example.com" }

      expect(response).to have_http_status(:redirect)
      # Check flash immediately after the response, before following redirect
      expect(flash[:alert]).to match(/Límite de solicitudes excedido/)
    end
  end

  describe "login rate limiting" do
    let(:user) { create(:user) }
    let(:login_limit) { 5 }

    it "allows requests under the limit" do
      login_limit.times do
        post session_path, params: { email: user.email, password: "wrongpassword" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).not_to match(/rate limit/i)
      end
    end

    it "blocks requests over the limit and shows error message" do
      # Make requests up to the limit
      login_limit.times do
        post session_path, params: { email: user.email, password: "wrongpassword" }
      end

      # Next request should be rate limited
      post session_path, params: { email: user.email, password: "wrongpassword" }

      expect(response).to have_http_status(:redirect)
      # Check flash immediately after the response, before following redirect
      expect(flash[:alert]).to match(/Límite de solicitudes excedido/)
    end
  end

  # The post-checkout landing page is public and retrieves the Checkout Session
  # from Stripe, so without a throttle anyone could drive outbound Stripe calls.
  describe "checkout success rate limiting" do
    let(:checkout_limit) { 20 }

    before { allow(Stripe::Checkout::Session).to receive(:retrieve).and_raise(Stripe::StripeError.new("nope")) }

    it "allows requests under the limit" do
      checkout_limit.times do
        get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }
        expect(response).to have_http_status(:success)
      end
    end

    it "blocks requests over the limit" do
      checkout_limit.times do
        get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }
      end

      get "/checkout/success", params: { stripe_checkout_session_id: "cs_test_123" }

      # Non-API paths get the redirect-with-flash responder, not a bare 429.
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to match(/Límite de solicitudes excedido/)
    end
  end
end
