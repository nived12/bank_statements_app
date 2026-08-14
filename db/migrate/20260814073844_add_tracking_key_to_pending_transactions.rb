class AddTrackingKeyToPendingTransactions < ActiveRecord::Migration[8.0]
  def change
    # A pending transaction is promoted into a real one on duplicate approval, so it
    # has to carry the SPEI clave too. Without this the key is silently dropped for
    # anything routed through duplicate review, and that transfer falls back to
    # amount+date matching for good.
    add_column :pending_transactions, :tracking_key, :string
  end
end
