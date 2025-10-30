# frozen_string_literal: true

##
# SavingCategory
# Junction model representing the many-to-many relationship between Savings and Categories
# Allows a saving to track multiple categories for auto-sync functionality
#
class SavingCategory < ApplicationRecord
  belongs_to :saving
  belongs_to :category

  validates :saving_id, uniqueness: { scope: :category_id, message: "Category already added to this saving" }
  validates :category_id, presence: true
  validates :saving_id, presence: true
end

# == Schema Information
#
# Table name: saving_categories
#
# Columns:
#  id                   :integer         not null   no default           no index
#  saving_id            :integer         not null   no default           index: index_saving_categories_on_saving_id, index_saving_categories_on_saving_id_and_category_id
#  category_id          :integer         not null   no default           index: index_saving_categories_on_category_id, index_saving_categories_on_saving_id_and_category_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_saving_categories_on_category_id (category_id) non-unique
#  index_saving_categories_on_saving_id (saving_id) non-unique
#  index_saving_categories_on_saving_id_and_category_id (saving_id, category_id) unique
#
