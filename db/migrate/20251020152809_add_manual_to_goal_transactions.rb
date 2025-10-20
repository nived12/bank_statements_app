class AddManualToGoalTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :goal_transactions, :manual, :boolean, default: true, null: false
  end
end
