require "rails_helper"

RSpec.describe "CategoryRules", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user, name: "Food") }
  let(:other_category) { create(:category, user: user, name: "Transport") }

  before { sign_in_user(user) }

  describe "GET /category_rules" do
    it "renders the index page" do
      get category_rules_path
      expect(response).to have_http_status(:success)
    end

    it "returns JSON" do
      create(:category_rule, user: user, category: category, pattern: "netflix")
      get category_rules_path, as: :json
      json = JSON.parse(response.body)
      expect(json["category_rules"].length).to eq(1)
      expect(json["category_rules"].first["pattern"]).to eq("netflix")
    end

    it "does not show other users rules" do
      other_user = create(:user)
      other_category_obj = create(:category, user: other_user)
      create(:category_rule, user: other_user, category: other_category_obj, pattern: "other")
      create(:category_rule, user: user, category: category, pattern: "mine")

      get category_rules_path, as: :json
      json = JSON.parse(response.body)
      patterns = json["category_rules"].map { |r| r["pattern"] }
      expect(patterns).to include("mine")
      expect(patterns).not_to include("other")
    end
  end

  describe "POST /category_rules" do
    context "with valid params" do
      it "creates a rule" do
        expect {
          post category_rules_path,
            params: { category_rule: { category_id: category.id, pattern: "netflix", match_type: "contains" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(CategoryRule, :count).by(1)
      end

      it "responds with turbo stream" do
        post category_rules_path,
          params: { category_rule: { category_id: category.id, pattern: "netflix", match_type: "contains" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "with invalid params" do
      it "does not create a rule without pattern" do
        expect {
          post category_rules_path,
            params: { category_rule: { category_id: category.id, pattern: "", match_type: "contains" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.not_to change(CategoryRule, :count)
      end
    end
  end

  describe "PATCH /category_rules/:id" do
    let!(:rule) { create(:category_rule, user: user, category: category, pattern: "netflix", active: true) }

    it "updates the active status" do
      patch category_rule_path(rule),
        params: { category_rule: { active: false } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" },
        as: :json

      expect(response).to have_http_status(:success)
      expect(rule.reload.active).to be(false)
    end

    it "responds with turbo stream" do
      patch category_rule_path(rule),
        params: { category_rule: { active: false } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" },
        as: :json

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("category-rule-#{rule.id}")
    end

    it "cannot update another user's rule" do
      other_user = create(:user)
      other_category_obj = create(:category, user: other_user)
      other_rule = create(:category_rule, user: other_user, category: other_category_obj, pattern: "other")

      patch category_rule_path(other_rule),
        params: { category_rule: { active: false } },
        as: :json

      expect(response).not_to have_http_status(:success)
    end
  end

  describe "DELETE /category_rules/:id" do
    let!(:rule) { create(:category_rule, user: user, category: category, pattern: "netflix") }

    it "destroys the rule" do
      expect {
        delete category_rule_path(rule),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(CategoryRule, :count).by(-1)
    end

    it "responds with turbo stream" do
      delete category_rule_path(rule),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("category-rule-#{rule.id}")
    end

    it "cannot delete another user's rule" do
      other_user = create(:user)
      other_category_obj = create(:category, user: other_user)
      other_rule = create(:category_rule, user: other_user, category: other_category_obj, pattern: "other")

      delete category_rule_path(other_rule),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).not_to have_http_status(:success)
    end
  end
end
