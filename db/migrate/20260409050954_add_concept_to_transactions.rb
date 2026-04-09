class AddConceptToTransactions < ActiveRecord::Migration[8.0]
  def up
    add_column :transactions, :concept, :string
    add_column :pending_transactions, :concept, :string

    # Backfill existing records with description as concept
    execute "UPDATE transactions SET concept = description WHERE concept IS NULL"
    execute "UPDATE pending_transactions SET concept = description WHERE concept IS NULL"
  end

  def down
    remove_column :transactions, :concept
    remove_column :pending_transactions, :concept
  end
end
