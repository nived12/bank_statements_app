class GoalTransaction < ApplicationRecord
  # Associations
  belongs_to :goal
  # Using 'txn' to avoid conflict with ActiveRecord's transaction method
  belongs_to :txn, class_name: "Transaction", foreign_key: "transaction_id"

  # Validations
  validates :goal_id, presence: true
  validates :transaction_id, presence: true
  validates :amount_applied, presence: true, numericality: { greater_than: 0 }

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
