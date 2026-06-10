require "rails_helper"

RSpec.describe "Finances", type: :request do
  let(:user) { create(:user) }

  describe "GET /finances" do
    it "redirects unauthenticated users to sign in" do
      get finances_path

      expect(response).to redirect_to(new_session_path)
    end

    context "when signed in" do
      before { sign_in_user(user) }

      it "loads the combined finances screen" do
        get finances_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t("navigation.finances"))
      end

      it "includes active savings, debts, and goals in the response" do
        saving = create(:saving, user: user, name: "E2E Emergency Fund")
        debt = create(:debt, user: user, name: "E2E Credit Card")
        goal = create(:goal, user: user, name: "E2E Vacation")

        get finances_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("E2E Emergency Fund")
        expect(response.body).to include("E2E Credit Card")
        expect(response.body).to include("E2E Vacation")
      end
    end
  end
end
