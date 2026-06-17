require "rails_helper"

RSpec.describe "Pricing", type: :request do
  describe "GET /pricing" do
    context "when unauthenticated" do
      it "renders the pricing page" do
        get pricing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("billing-toggle")
        expect(response.body).to include(new_user_path)
      end

      it "renders English copy when ?locale=en" do
        get pricing_path(locale: :en)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-lang="en"')
      end

      it "shows 30-day trial CTA for guests" do
        get pricing_path
        expect(response.body).to include("30")
        expect(response.body).to include(new_user_path)
      end
    end

    context "when authenticated with active subscription" do
      let(:user) { create(:user) }

      before do
        allow_any_instance_of(User).to receive(:active_paid_subscription?).and_return(true)
        post session_path, params: { email: user.email, password: "secret123" }
      end

      it "shows portal CTA for premium users" do
        get pricing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(portal_subscription_path)
      end
    end
  end
end
