require "rails_helper"

RSpec.describe CategoryRules::Creator do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:other_category) { create(:category, user: user, name: "Other") }
  let(:bank_account) { create(:bank_account, user: user) }

  describe "#call" do
    context "when transaction has a category" do
      let(:transaction) do
        create(
          :transaction, user: user, bank_account: bank_account, category: category,
          description: "STARBUCKS COFFEE 000123456"
        )
      end

      it "creates a new category rule" do
        expect { described_class.call(transaction) }.to change(CategoryRule, :count).by(1)
      end

      it "normalizes the description as the pattern" do
        result = described_class.call(transaction)
        expect(result.payload.pattern).to eq("starbucks coffee")
      end

      it "sets match_type to contains" do
        result = described_class.call(transaction)
        expect(result.payload.match_type).to eq("contains")
      end

      it "sets auto_generated to true" do
        result = described_class.call(transaction)
        expect(result.payload.auto_generated).to be(true)
      end

      it "sets the correct category" do
        result = described_class.call(transaction)
        expect(result.payload.category_id).to eq(category.id)
      end

      it "returns success" do
        result = described_class.call(transaction)
        expect(result).to be_success
      end
    end

    context "when a rule already exists for the same pattern" do
      let!(:existing_rule) do
        create(
          :category_rule, user: user, category: category,
          pattern: "starbucks coffee", match_type: "contains"
        )
      end

      let(:transaction) do
        create(
          :transaction, user: user, bank_account: bank_account, category: other_category,
          description: "STARBUCKS COFFEE 00001234"
        )
      end

      it "does not create a new rule" do
        expect { described_class.call(transaction) }.not_to change(CategoryRule, :count)
      end

      it "updates the category on the existing rule" do
        described_class.call(transaction)
        expect(existing_rule.reload.category_id).to eq(other_category.id)
      end

      it "preserves auto_generated flag on existing rules" do
        existing_rule.update!(auto_generated: false)
        described_class.call(transaction)
        expect(existing_rule.reload.auto_generated).to be(false)
      end

      it "reactivates inactive rules" do
        existing_rule.update!(active: false)
        described_class.call(transaction)
        expect(existing_rule.reload.active).to be(true)
      end
    end

    context "when transaction has no category" do
      let(:transaction) do
        create(
          :transaction, user: user, bank_account: bank_account, category: nil,
          description: "Some description"
        )
      end

      it "returns failure" do
        result = described_class.call(transaction)
        expect(result).to be_failure
      end

      it "does not create a rule" do
        expect { described_class.call(transaction) }.not_to change(CategoryRule, :count)
      end
    end

    context "when description normalizes to empty" do
      it "returns failure" do
        transaction = build(
          :transaction, user: user, bank_account: bank_account, category: category,
          description: "1234567890"
        )
        # Stub to bypass validation
        allow(transaction).to receive(:description).and_return("1234567890")

        result = described_class.call(transaction)
        expect(result).to be_failure
      end
    end
  end
end
