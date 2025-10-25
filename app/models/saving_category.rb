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
