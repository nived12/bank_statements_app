class GoalTransaction < ApplicationRecord
  # Associations
  belongs_to :goal
  # Using 'txn' to avoid conflict with ActiveRecord's transaction method
  belongs_to :txn, class_name: "Transaction", foreign_key: "transaction_id"

  # Validations
  validates :goal_id, presence: true
  validates :transaction_id, presence: true
  validates :amount_applied, presence: true, numericality: { other_than: 0 }

  # Ensure unique goal-transaction pair
  validates :transaction_id, uniqueness: { scope: :goal_id, message: "is already linked to this goal" }

  # Callbacks
  after_save :update_goal_current_amount
  after_destroy :update_goal_current_amount

  private

  # Update the goal's current_amount after linking/unlinking transactions
  def update_goal_current_amount
    goal.recalculate_current_amount! if goal.present?
  end
end

# == Schema Information
#
# Table name: goal_transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  goal_id              :integer         not null   no default           index: index_goal_transactions_on_goal_id, index_goal_transactions_on_goal_id_and_transaction_id
#  transaction_id       :integer         not null   no default           index: index_goal_transactions_on_goal_id_and_transaction_id, index_goal_transactions_on_transaction_id
#  amount_applied       :decimal         not null   no default           no index
#  notes                :text            null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  manual               :boolean         not null   default: true        no index
#
# Indexes:
#  index_goal_transactions_on_goal_id (goal_id) non-unique
#  index_goal_transactions_on_goal_id_and_transaction_id (goal_id, transaction_id) unique
#  index_goal_transactions_on_transaction_id (transaction_id) non-unique
#
