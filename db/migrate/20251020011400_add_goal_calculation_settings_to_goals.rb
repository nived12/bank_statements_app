class AddGoalCalculationSettingsToGoals < ActiveRecord::Migration[7.2]
  def change
    add_column :goals, :goal_calculation_settings, :jsonb, default: {}, null: false
    remove_column :goals, :track_reverse_transactions, :boolean
  end
end
