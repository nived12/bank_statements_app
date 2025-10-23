class CreateGoalDebts < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_debts do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :debt, null: false, foreign_key: true

      t.timestamps
    end
  end
end
