class CategoryRule < ApplicationRecord
  belongs_to :user
  belongs_to :category

  enum :match_type, { exact: "exact", contains: "contains", starts_with: "starts_with" }

  validates :pattern, presence: true
  validates :pattern, uniqueness: { scope: [:user_id, :match_type] }
  validates :priority, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :desc, hits_count: :desc) }
end
