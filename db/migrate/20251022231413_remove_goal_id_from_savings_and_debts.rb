class RemoveGoalIdFromSavingsAndDebts < ActiveRecord::Migration[8.0]
  def change
    remove_column :savings, :goal_id, :integer
    remove_column :debts, :goal_id, :integer
  end
end
