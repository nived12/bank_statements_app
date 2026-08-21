class CategoryRule < ApplicationRecord
  belongs_to :user
  belongs_to :category

  enum :match_type, { exact: "exact", contains: "contains", starts_with: "starts_with" }

  validates :pattern, presence: true
  validates :pattern, uniqueness: { scope: [:user_id, :match_type] }
  validates :priority, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  # Longest pattern first so the rule naming a specific account beats the generic one
  # that would otherwise swallow it — every learned rule shares priority 0.
  scope :by_priority, lambda {
    order(priority: :desc).order(Arel.sql("LENGTH(pattern) DESC")).order(hits_count: :desc)
  }
end

# == Schema Information
#
# Table name: category_rules
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: idx_category_rules_user_active, idx_category_rules_user_pattern_match, index_category_rules_on_user_id
#  category_id          :integer         not null   no default           index: index_category_rules_on_category_id
#  match_type           :string          not null   default: contains    index: idx_category_rules_user_pattern_match
#  pattern              :string          not null   no default           index: idx_category_rules_user_pattern_match
#  priority             :integer         not null   default: 0           no index
#  hits_count           :integer         not null   default: 0           no index
#  active               :boolean         not null   default: true        index: idx_category_rules_user_active
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  idx_category_rules_user_active (user_id, active) non-unique
#  idx_category_rules_user_pattern_match (user_id, pattern, match_type) unique
#  index_category_rules_on_category_id (category_id) non-unique
#  index_category_rules_on_user_id (user_id) non-unique
#
