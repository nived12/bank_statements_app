class CreateGoalTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_transactions do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true
      t.decimal :amount_applied, precision: 12, scale: 2, null: false
      t.text :notes, null: true

      t.timestamps
    end

    add_index :goal_transactions, [:goal_id, :transaction_id], unique: true
  end
end
