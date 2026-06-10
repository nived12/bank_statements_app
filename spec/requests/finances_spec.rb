require "rails_helper"

RSpec.describe "Finances", type: :request do
  let(:user) { create(:user) }

  before { sign_in_user(user) }

  describe "GET /finances" do
    it "loads the combined finances screen" do
      get finances_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("navigation.finances"))
    end
  end
end
