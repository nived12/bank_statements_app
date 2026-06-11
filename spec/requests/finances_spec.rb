# frozen_string_literal: true

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
        debt   = create(:debt,   user: user, name: "E2E Credit Card")
        goal   = create(:goal,   user: user, name: "E2E Vacation")

        get finances_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("E2E Emergency Fund")
        expect(response.body).to include("E2E Credit Card")
        expect(response.body).to include("E2E Vacation")
      end

      it "excludes non-active records" do
        create(:saving, :archived, user: user, name: "Archived Saving")
        create(:saving, :completed, user: user, name: "Completed Saving")
        create(:debt,   :paid_off,  user: user, name: "Paid Off Debt")
        create(:goal,   :archived,  user: user, name: "Archived Goal")

        get finances_path

        expect(response.body).not_to include("Archived Saving")
        expect(response.body).not_to include("Completed Saving")
        expect(response.body).not_to include("Paid Off Debt")
        expect(response.body).not_to include("Archived Goal")
      end

      it "returns empty state when user has no active records" do
        get finances_path

        expect(response).to have_http_status(:success)
      end

      it "renders records in created_at desc order" do
        older  = create(:saving, user: user, name: "Older Saving",  created_at: 2.days.ago)
        newer  = create(:saving, user: user, name: "Newer Saving",  created_at: 1.hour.ago)

        get finances_path

        older_pos = response.body.index("Older Saving")
        newer_pos = response.body.index("Newer Saving")
        expect(newer_pos).to be < older_pos
      end
    end
  end
end
