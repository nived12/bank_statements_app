class AddDiscardedAtToBankAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :bank_accounts, :discarded_at, :datetime
    add_index :bank_accounts, :discarded_at
  end
end
