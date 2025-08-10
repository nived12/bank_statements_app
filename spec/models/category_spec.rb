require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user, name: "Test Category") }
  let(:parent_category) { create(:category, user: user, name: "Parent Category") }
  let(:child_category) { create(:category, user: user, name: "Child Category", parent: parent_category) }

  describe "associations" do
    it "belongs to a user" do
      expect(category.user).to be_present
    end

    it "belongs to a parent category" do
      expect(child_category.parent).to eq(parent_category)
    end

    it "has many children" do
      expect(parent_category.children).to include(child_category)
    end

    it "has many transactions" do
      expect(category.transactions).to be_empty
    end
  end

  describe "validations" do
    it "is valid with a name" do
      expect(category).to be_valid
    end

    it "requires a name" do
      category.name = nil
      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it "is valid without a user (global category)" do
      global_category = build(:category, user: nil, name: "Global Category")
      expect(global_category).to be_valid
    end

    it "is valid without a parent (top-level category)" do
      top_level_category = build(:category, user: user, parent: nil, name: "Top Level")
      expect(top_level_category).to be_valid
    end
  end

  describe "hierarchical structure" do
    it "can have a parent category" do
      expect(child_category.parent).to eq(parent_category)
    end

    it "can have child categories" do
      expect(parent_category.children).to include(child_category)
    end

    it "can be a top-level category" do
      expect(parent_category.parent).to be_nil
    end

    it "can be a leaf category" do
      expect(child_category.children).to be_empty
    end
  end

  describe "scopes and queries" do
    let!(:top_level_categories) do
      [
        create(:category, user: user, parent: nil, name: "Top Level 1"),
        create(:category, user: user, parent: nil, name: "Top Level 2"),
        create(:category, user: user, parent: nil, name: "Top Level 3")
      ]
    end
    let!(:child_categories) do
      [
        create(:category, user: user, parent: top_level_categories.first, name: "Child 1"),
        create(:category, user: user, parent: top_level_categories.first, name: "Child 2")
      ]
    end

    it "can find top-level categories" do
      expect(Category.where(parent: nil)).to match_array(top_level_categories)
    end

    it "can find child categories" do
      expect(Category.where.not(parent: nil)).to match_array(child_categories)
    end
  end

  describe "user scoping" do
    let(:other_user) { create(:user) }
    let!(:user_category) { create(:category, user: user, name: "User Category") }
    let!(:other_user_category) { create(:category, user: other_user, name: "Other User Category") }
    let!(:global_category) { create(:category, user: nil, name: "Global Category") }

    it "can find categories for a specific user" do
      expect(Category.where(user: user)).to include(user_category)
      expect(Category.where(user: user)).not_to include(other_user_category)
    end

    it "can find global categories" do
      expect(Category.where(user: nil)).to include(global_category)
    end
  end

  describe "naming and uniqueness" do
    it "allows different names for the same user" do
      category1 = create(:category, user: user, name: "Category 1")
      category2 = create(:category, user: user, name: "Category 2")
      expect(category1).to be_valid
      expect(category2).to be_valid
    end

    it "allows the same name for different users" do
      other_user = create(:user)
      category1 = create(:category, user: user, name: "Same Name")
      category2 = create(:category, user: other_user, name: "Same Name")
      expect(category1).to be_valid
      expect(category2).to be_valid
    end

    it "allows the same name for global categories" do
      global1 = create(:category, user: nil, name: "Global Name")
      global2 = create(:category, user: nil, name: "Global Name")
      expect(global1).to be_valid
      expect(global2).to be_valid
    end
  end

  describe "destruction behavior" do
    let!(:category_with_children) { create(:category, user: user, name: "Parent") }
    let!(:child) { create(:category, user: user, name: "Child", parent: category_with_children) }

    it "prevents destruction when it has children" do
      expect { category_with_children.destroy }.not_to change { Category.count }
      expect(category_with_children.errors[:base]).to include("Cannot delete record because dependent children exist")
    end

    it "allows destruction when it has no children" do
      expect { child.destroy }.to change { Category.count }.by(-1)
    end
  end

  describe "transaction relationships" do
    let!(:transaction) { create(:transaction, user: user, category: category) }

    it "can have transactions" do
      expect(category.transactions).to include(transaction)
    end

    it "nullifies transactions when destroyed" do
      category.destroy
      transaction.reload
      expect(transaction.category).to be_nil
    end
  end
end
