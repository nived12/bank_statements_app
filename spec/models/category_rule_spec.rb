require "rails_helper"

RSpec.describe CategoryRule, type: :model do
  describe "associations" do
    it "belongs to user" do
      rule = build(:category_rule)
      expect(rule).to respond_to(:user)
      expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it "belongs to category" do
      rule = build(:category_rule)
      expect(rule).to respond_to(:category)
      expect(described_class.reflect_on_association(:category).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    it "requires pattern" do
      rule = build(:category_rule, pattern: nil)
      expect(rule).not_to be_valid
      expect(rule.errors[:pattern]).to be_present
    end

    it "requires integer priority" do
      rule = build(:category_rule, priority: 1.5)
      expect(rule).not_to be_valid
      expect(rule.errors[:priority]).to be_present
    end

    it "validates uniqueness of pattern scoped to user_id and match_type" do
      user = create(:user)
      category = create(:category, user: user)
      create(:category_rule, user: user, category: category, pattern: "netflix", match_type: "contains")

      duplicate = build(:category_rule, user: user, category: category, pattern: "netflix", match_type: "contains")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:pattern]).to be_present
    end

    it "allows same pattern with different match_type" do
      user = create(:user)
      category = create(:category, user: user)
      create(:category_rule, user: user, category: category, pattern: "netflix", match_type: "contains")

      different_type = build(:category_rule, user: user, category: category, pattern: "netflix", match_type: "exact")
      expect(different_type).to be_valid
    end

    it "allows same pattern for different users" do
      category = create(:category)
      user1 = create(:user)
      user2 = create(:user)
      create(:category_rule, user: user1, category: category, pattern: "netflix", match_type: "contains")

      other_user_rule = build(
        :category_rule, user: user2, category: category, pattern: "netflix",
        match_type: "contains"
      )
      expect(other_user_rule).to be_valid
    end
  end

  describe "enums" do
    it "defines match_type enum with string values" do
      expect(described_class.match_types).to eq(
        "exact" => "exact",
        "contains" => "contains",
        "starts_with" => "starts_with"
      )
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:category) { create(:category, user: user) }

    describe ".active" do
      it "returns only active rules" do
        active_rule = create(:category_rule, user: user, category: category, pattern: "active", active: true)
        create(:category_rule, user: user, category: category, pattern: "inactive", active: false)

        expect(described_class.active).to eq([active_rule])
      end
    end

    describe ".by_priority" do
      it "orders by priority desc then hits_count desc" do
        low_priority = create(
          :category_rule, user: user, category: category, pattern: "low", priority: 0,
          hits_count: 10
        )
        high_priority = create(
          :category_rule, user: user, category: category, pattern: "high", priority: 5,
          hits_count: 0
        )
        same_priority_more_hits = create(
          :category_rule, user: user, category: category, pattern: "same", priority: 5,
          hits_count: 20
        )

        expect(described_class.by_priority).to eq([same_priority_more_hits, high_priority, low_priority])
      end
    end
  end

  describe "defaults" do
    it "sets sensible defaults" do
      rule = described_class.new
      expect(rule.match_type).to eq("contains")
      expect(rule.priority).to eq(0)
      expect(rule.hits_count).to eq(0)
      expect(rule.active).to be(true)
    end
  end
end
