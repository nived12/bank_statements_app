require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "bbva") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }

  before do
    sign_in_user_with_locale(user)
  end

  describe "GET /dashboard" do
    it "loads dashboard successfully" do
      get "/es/dashboard"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end

    it "handles authentication properly" do
      get "/es/dashboard"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end
end
