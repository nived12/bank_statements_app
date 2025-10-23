class GoalSaving < ApplicationRecord
  belongs_to :goal
  belongs_to :saving

  validates :goal_id, presence: true
  validates :saving_id, presence: true
  validates :saving_id, uniqueness: { scope: :goal_id, message: "is already associated with this goal" }
end

# == Schema Information
#
# Table name: goal_savings
#
# Columns:
#  id                   :integer         not null   no default           no index
#  goal_id              :integer         not null   no default           index: index_goal_savings_on_goal_id
#  saving_id            :integer         not null   no default           index: index_goal_savings_on_saving_id
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_goal_savings_on_goal_id  (goal_id) non-unique
#  index_goal_savings_on_saving_id (saving_id) non-unique
#
