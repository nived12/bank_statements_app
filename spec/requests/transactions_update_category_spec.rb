require "rails_helper"

RSpec.describe "Transactions#update_category", type: :request do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:category) { create(:category, user: user, name: "Food") }
  let(:new_category) { create(:category, user: user, name: "Transport") }
  let(:transaction) do
    create(
      :transaction, user: user, bank_account: bank_account, category: category,
      description: "UBER EATS ORDER 12345"
    )
  end

  before { sign_in_user(user) }

  describe "PATCH /transactions/:id/update_category" do
    context "with valid category" do
      it "updates the transaction category" do
        patch update_category_transaction_path(transaction),
          params: { category_id: new_category.id },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

        expect(response).to have_http_status(:success)
        expect(transaction.reload.category_id).to eq(new_category.id)
      end

      it "creates a category rule automatically" do
        expect {
          patch update_category_transaction_path(transaction),
            params: { category_id: new_category.id },
            headers: { "Accept" => "text/vnd.turbo-stream.html" },
            as: :json
        }.to change(CategoryRule, :count).by(1)

        rule = CategoryRule.last
        expect(rule.user_id).to eq(user.id)
        expect(rule.category_id).to eq(new_category.id)
        expect(rule.match_type).to eq("contains")
      end

      it "responds with turbo stream" do
        patch update_category_transaction_path(transaction),
          params: { category_id: new_category.id },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("transaction-category-desktop-#{transaction.id}")
        expect(response.body).to include("transaction-category-mobile-#{transaction.id}")
      end
    end

    context "clearing category" do
      it "removes the category" do
        patch update_category_transaction_path(transaction),
          params: { category_id: nil },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

        expect(response).to have_http_status(:success)
        expect(transaction.reload.category_id).to be_nil
      end
    end

    context "with JSON format" do
      it "responds with JSON" do
        patch update_category_transaction_path(transaction),
          params: { category_id: new_category.id },
          as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be(true)
        expect(json["category_id"]).to eq(new_category.id)
      end
    end

    context "authorization" do
      let(:other_user) { create(:user) }
      let(:other_transaction) do
        other_account = create(:bank_account, user: other_user)
        create(:transaction, user: other_user, bank_account: other_account, category: category)
      end

      it "cannot update another user's transaction" do
        patch update_category_transaction_path(other_transaction),
          params: { category_id: new_category.id },
          as: :json

        expect(response).not_to have_http_status(:success)
      end
    end
  end
end
