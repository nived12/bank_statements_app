require "rails_helper"

RSpec.describe CategoryRules::Matcher do
  let(:user) { create(:user) }
  let(:parent_category) { create(:category, user: user, name: "Food") }
  let(:child_category) { create(:category, user: user, name: "Restaurants", parent: parent_category) }
  let(:other_category) { create(:category, user: user, name: "Transport") }

  describe "#call" do
    context "with matching rules" do
      before do
        create(:category_rule, user: user, category: child_category,
               pattern: "uber eats", match_type: "contains")
        create(:category_rule, user: user, category: other_category,
               pattern: "uber trip", match_type: "contains")
      end

      it "matches transactions against contains rules" do
        transactions = [
          { "description" => "UBER EATS ORDER 12345", "amount" => "-150.00" },
          { "description" => "WALMART SUPERCENTER", "amount" => "-300.00" }
        ]

        result = described_class.call(user: user, transactions: transactions)

        expect(result).to be_success
        expect(result.payload[:matched].length).to eq(1)
        expect(result.payload[:unmatched].length).to eq(1)
      end

      it "sets category_id and sub_category_id for child categories" do
        transactions = [{ "description" => "UBER EATS ORDER 12345" }]

        result = described_class.call(user: user, transactions: transactions)
        matched = result.payload[:matched].first

        expect(matched["category_id"]).to eq(parent_category.id)
        expect(matched["sub_category_id"]).to eq(child_category.id)
        expect(matched["category_confidence"]).to eq(0.95)
      end

      it "sets only category_id for parent categories" do
        create(:category_rule, user: user, category: parent_category,
               pattern: "restaurant generico", match_type: "contains")

        transactions = [{ "description" => "RESTAURANT GENERICO ABC" }]
        result = described_class.call(user: user, transactions: transactions)
        matched = result.payload[:matched].first

        expect(matched["category_id"]).to eq(parent_category.id)
        expect(matched["sub_category_id"]).to be_nil
      end

      it "increments hits_count for matched rules" do
        rule = user.category_rules.find_by(pattern: "uber eats")
        transactions = [{ "description" => "UBER EATS ORDER 999" }]

        expect {
          described_class.call(user: user, transactions: transactions)
        }.to change { rule.reload.hits_count }.by(1)
      end

      it "matches the first rule when multiple could match" do
        transactions = [{ "description" => "UBER TRIP 123" }]

        result = described_class.call(user: user, transactions: transactions)
        matched = result.payload[:matched].first

        # Should match "uber trip" → Transport, not "uber eats"
        expect(matched["category_id"]).to eq(other_category.id)
      end
    end

    context "with different match types" do
      it "matches exact rules" do
        create(:category_rule, user: user, category: other_category,
               pattern: "netflix subscription", match_type: "exact")

        transactions = [
          { "description" => "NETFLIX SUBSCRIPTION" },
          { "description" => "NETFLIX SUBSCRIPTION EXTRA" }
        ]

        result = described_class.call(user: user, transactions: transactions)

        expect(result.payload[:matched].length).to eq(1)
        expect(result.payload[:unmatched].length).to eq(1)
      end

      it "matches starts_with rules" do
        create(:category_rule, user: user, category: other_category,
               pattern: "pago tarjeta", match_type: "starts_with")

        transactions = [
          { "description" => "PAGO TARJETA 000123456" },
          { "description" => "ABONO PAGO TARJETA" }
        ]

        result = described_class.call(user: user, transactions: transactions)

        expect(result.payload[:matched].length).to eq(1)
        expect(result.payload[:unmatched].length).to eq(1)
      end
    end

    context "with no rules" do
      it "returns all transactions as unmatched" do
        transactions = [{ "description" => "Something" }]

        result = described_class.call(user: user, transactions: transactions)

        expect(result.payload[:matched]).to be_empty
        expect(result.payload[:unmatched].length).to eq(1)
      end
    end

    context "with empty transactions" do
      it "returns empty arrays" do
        create(:category_rule, user: user, category: other_category, pattern: "test")

        result = described_class.call(user: user, transactions: [])

        expect(result.payload[:matched]).to be_empty
        expect(result.payload[:unmatched]).to be_empty
      end
    end

    context "with inactive rules" do
      it "ignores inactive rules" do
        create(:category_rule, user: user, category: other_category,
               pattern: "netflix", match_type: "contains", active: false)

        transactions = [{ "description" => "NETFLIX SUBSCRIPTION" }]

        result = described_class.call(user: user, transactions: transactions)

        expect(result.payload[:matched]).to be_empty
        expect(result.payload[:unmatched].length).to eq(1)
      end
    end

    context "with symbol keys in transactions" do
      it "handles symbol keys for description" do
        create(:category_rule, user: user, category: other_category,
               pattern: "starbucks", match_type: "contains")

        transactions = [{ description: "STARBUCKS COFFEE" }]

        result = described_class.call(user: user, transactions: transactions)

        expect(result.payload[:matched].length).to eq(1)
      end
    end
  end
end
