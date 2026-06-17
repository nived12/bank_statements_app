require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET /" do
    context "when unauthenticated" do
      it "renders the landing page with a signup CTA" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("hero-title")
        expect(response.body).to include(new_user_path)
      end

      it "renders English copy when ?locale=en" do
        get root_path(locale: :en)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-lang="en"')
      end
    end

    context "when authenticated" do
      let(:user) { create(:user) }

      before { post session_path, params: { email: user.email, password: "secret123" } }

      it "renders the dashboard" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("hero-title")
      end
    end
  end
end
