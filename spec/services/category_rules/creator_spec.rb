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

  # Statement imports fan out across Sidekiq workers, so two can correct the same
  # description at once. The unique index on (user_id, pattern, match_type) is what
  # stops a duplicate, and the loser of that race has to recover rather than raise.
  describe "when a concurrent worker wins the race" do
    let(:user) { create(:user) }
    let(:category) { create(:category, user: user) }
    let(:other_category) { create(:category, user: user, name: "Otra") }
    let(:transaction) do
      create(:transaction, user: user, description: "OXXO SUCURSAL 12", category: category)
    end

    it "adopts the rule the other worker created and points it at this category" do
      existing = create(
        :category_rule,
        user: user, category: other_category, pattern: "oxxo sucursal 12",
        match_type: "contains", active: false
      )
      # Stub only the record the service builds, so the recovery path's own update
      # stays real — stubbing every instance makes the retry raise again.
      doomed = CategoryRule.new(user: user, pattern: "oxxo sucursal 12", match_type: "contains")
      allow(CategoryRule).to receive(:find_or_initialize_by).and_return(doomed)
      allow(doomed).to receive(:save).and_raise(ActiveRecord::RecordNotUnique, "dup")

      result = described_class.call(transaction)

      expect(result).to be_success
      expect(existing.reload.category_id).to eq(category.id)
      expect(existing.reload).to be_active
    end
  end

  describe "when the rule cannot be saved" do
    let(:user) { create(:user) }
    let(:category) { create(:category, user: user) }
    let(:transaction) do
      create(:transaction, user: user, description: "OXXO SUCURSAL 12", category: category)
    end

    it "surfaces the record's errors rather than failing silently" do
      unsavable = CategoryRule.new(user: user, pattern: "oxxo sucursal 12", match_type: "contains")
      allow(CategoryRule).to receive(:find_or_initialize_by).and_return(unsavable)
      allow(unsavable).to receive(:save).and_return(false)
      allow(unsavable).to receive(:errors).and_return(
        ActiveModel::Errors.new(unsavable).tap { |e| e.add(:pattern, "is invalid") }
      )

      result = described_class.call(transaction)

      expect(result).to be_failure
      expect(result.errors.full_messages.join).to include("is invalid")
    end
  end
end
