class GoalDebt < ApplicationRecord
  belongs_to :goal
  belongs_to :debt

  validates :goal_id, presence: true
  validates :debt_id, presence: true
  validates :debt_id, uniqueness: { scope: :goal_id, message: "is already associated with this goal" }
end

# == Schema Information
#
# Table name: goal_debts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  goal_id              :integer         not null   no default           index: index_goal_debts_on_goal_id
#  debt_id              :integer         not null   no default           index: index_goal_debts_on_debt_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_goal_debts_on_debt_id    (debt_id) non-unique
#  index_goal_debts_on_goal_id    (goal_id) non-unique
#

