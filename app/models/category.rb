class Category < ApplicationRecord
  belongs_to :user, optional: true  # nil => global
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error # Subcategories
  has_many :transactions, dependent: :nullify

  validates :name, presence: true
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
#
# Indexes:
#  idx_categories_user_parent_name (user_id, parent_id, name) unique
#  index_categories_on_parent_id  (parent_id) non-unique
#  index_categories_on_user_id    (user_id) non-unique
#
