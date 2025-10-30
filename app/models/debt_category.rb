# frozen_string_literal: true

##
# DebtCategory
# Junction model representing the many-to-many relationship between Debts and Categories
# Allows a debt to track multiple categories for auto-sync functionality
#
class DebtCategory < ApplicationRecord
  belongs_to :debt
  belongs_to :category

  validates :debt_id, uniqueness: { scope: :category_id, message: "Category already added to this debt" }
  validates :category_id, presence: true
  validates :debt_id, presence: true
end

# == Schema Information
#
# Table name: debt_categories
#
# Columns:
#  id                   :integer         not null   no default           no index
#  debt_id              :integer         not null   no default           index: index_debt_categories_on_debt_id, index_debt_categories_on_debt_id_and_category_id
#  category_id          :integer         not null   no default           index: index_debt_categories_on_category_id, index_debt_categories_on_debt_id_and_category_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_debt_categories_on_category_id (category_id) non-unique
#  index_debt_categories_on_debt_id (debt_id) non-unique
#  index_debt_categories_on_debt_id_and_category_id (debt_id, category_id) unique
#
