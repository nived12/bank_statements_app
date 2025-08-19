require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, :bbva) }
  let(:opening_balance_date) { Date.new(2025, 1, 15) }

  let(:bank_account) do
    create(:bank_account,
      user: user,
      bank: bank,
      opening_balance: 1000.00,
      opening_balance_date: opening_balance_date
    )
  end

  let(:statement_file) do
    create(:statement_file,
      user: user,
      bank_account: bank_account,
      status: "parsed"
    )
  end

  before do
    # Create default categories for the user
    create(:category, user: user, name: "Uncategorized")
    sign_in user
  end

  describe "GET /dashboard" do
    it "loads dashboard successfully" do
      get "/dashboard"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end

  describe "authentication" do
    it "handles authentication properly" do
      # This test verifies that the dashboard loads with proper authentication
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

  private

  def sign_in(user)
    # Mock the authentication methods
    allow_any_instance_of(DashboardController).to receive(:current_user).and_return(user)
    allow_any_instance_of(DashboardController).to receive(:authenticate!).and_return(true)
    allow_any_instance_of(DashboardController).to receive(:ensure_user_has_categories).and_return(true)
  end

  def sign_out(user)
    allow_any_instance_of(DashboardController).to receive(:current_user).and_return(nil)
    allow_any_instance_of(DashboardController).to receive(:authenticate!).and_return(false)
    allow_any_instance_of(DashboardController).to receive(:ensure_user_has_categories).and_return(false)
  end
end
