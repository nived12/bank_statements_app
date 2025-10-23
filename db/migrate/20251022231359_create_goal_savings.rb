class CreateGoalSavings < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_savings do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :saving, null: false, foreign_key: true

      t.timestamps
    end
  end
end
