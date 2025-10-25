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
