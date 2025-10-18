class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :goal_type, null: false
      t.decimal :target_amount, precision: 12, scale: 2, null: false
      t.decimal :current_amount, precision: 12, scale: 2, default: 0, null: false
      t.date :start_date, null: false
      t.date :deadline, null: false
      t.references :category, null: true, foreign_key: true
      t.boolean :auto_link_category, default: false, null: false
      t.string :debt_strategy, null: true
      t.decimal :starting_debt_amount, precision: 12, scale: 2, null: true
      t.string :icon, null: true
      t.string :color, default: "#3B82F6", null: false
      t.string :status, default: "active", null: false
      t.text :notes, null: true

      t.timestamps
    end

    add_index :goals, :goal_type
    add_index :goals, :deadline
    add_index :goals, :status
    add_index :goals, [:user_id, :status]
  end
end
