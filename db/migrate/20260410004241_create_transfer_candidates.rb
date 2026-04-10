class CreateTransferCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :transfer_candidates do |t|
      t.references :user, null: false, foreign_key: true
      t.references :outgoing_transaction, null: false, foreign_key: { to_table: :transactions }
      t.references :incoming_transaction, null: false, foreign_key: { to_table: :transactions }
      t.string :status, null: false, default: "pending"
      t.decimal :similarity_score, precision: 3, scale: 2

      t.timestamps
    end

    add_index :transfer_candidates,
      %i[outgoing_transaction_id incoming_transaction_id],
      unique: true,
      name: "idx_transfer_candidates_pair"
    add_index :transfer_candidates, %i[user_id status]
  end
end
