class DropGoalTransactions < ActiveRecord::Migration[8.0]
  def up
    drop_table :goal_transactions
  end

  def down
    create_table :goal_transactions do |t|
      t.bigint :goal_id, null: false
      t.bigint :transaction_id, null: false
      t.decimal :amount_applied, precision: 12, scale: 2, null: false
      t.text :notes
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.boolean :manual, default: true, null: false

      t.index [:goal_id, :transaction_id], name: "index_goal_transactions_on_goal_id_and_transaction_id", unique: true
      t.index :goal_id, name: "index_goal_transactions_on_goal_id"
      t.index :transaction_id, name: "index_goal_transactions_on_transaction_id"
    end

    add_foreign_key :goal_transactions, :goals
    add_foreign_key :goal_transactions, :transactions
  end
end
