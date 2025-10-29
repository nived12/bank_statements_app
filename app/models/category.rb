class Category < ApplicationRecord
  belongs_to :user, optional: true  # nil => global
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error # Subcategories
  has_many :transactions, dependent: :nullify
  has_many :saving_categories, dependent: :destroy
  has_many :savings, through: :saving_categories
  has_many :debt_categories, dependent: :destroy
  has_many :debts, through: :debt_categories

  validates :name, presence: true

  # Scope to order categories hierarchically: parent categories first, then their children
  scope :hierarchical_order, -> {
    # Get all categories and sort them in Ruby to maintain parent-child grouping
    all.sort_by do |category|
      if category.parent_id.nil?
        # Parent categories: sort by name
        [category.name, ""]
      else
        # Child categories: sort by parent name, then own name
        parent = Category.find_by(id: category.parent_id)
        [parent&.name || "", category.name]
      end
    end
  }
end

# == Schema Information
#
# Table name: categories
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         null       no default           index: idx_categories_user_parent_name, index_categories_on_user_id
#  name                 :string          not null   no default           index: idx_categories_user_parent_name
#  parent_id            :integer         null       no default           index: idx_categories_user_parent_name, index_categories_on_parent_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  icon                 :string          null       no default           no index
#
# Indexes:
#  idx_categories_user_parent_name (user_id, parent_id, name) unique
#  index_categories_on_parent_id  (parent_id) non-unique
#  index_categories_on_user_id    (user_id) non-unique
#
