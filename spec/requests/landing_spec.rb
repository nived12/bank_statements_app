require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET /" do
    context "when unauthenticated" do
      it "renders the landing page" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("waitlist")
      end
    end

    context "when authenticated" do
      let(:user) { create(:user) }

      before { post session_path, params: { email: user.email, password: "secret123" } }

      it "renders the dashboard" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("waitlist")
      end
    end
  end
end
