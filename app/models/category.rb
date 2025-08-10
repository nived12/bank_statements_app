class Category < ApplicationRecord
  belongs_to :user, optional: true  # nil => global
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :restrict_with_error # Subcategories
  has_many :transactions, dependent: :nullify

  validates :name, presence: true
end
