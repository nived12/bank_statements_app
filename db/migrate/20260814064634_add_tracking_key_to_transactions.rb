class AddTrackingKeyToTransactions < ActiveRecord::Migration[8.0]
  def change
    # SPEI clave de rastreo. Both banks print the same key for the same operation,
    # so it pairs the two sides of a transfer exactly. Nullable: only interbank
    # transfers carry one, and older rows predate its capture.
    add_column :transactions, :tracking_key, :string

    # The reconciler looks keys up per user, never globally.
    add_index :transactions, [:user_id, :tracking_key],
      where: "tracking_key IS NOT NULL",
      name: "index_transactions_on_user_id_and_tracking_key"
  end
end
