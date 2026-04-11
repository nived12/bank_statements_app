class AddBelvoToBankAccounts < ActiveRecord::Migration[8.0]
  def change
    add_reference :bank_accounts, :belvo_link, foreign_key: true, index: true, null: true
    add_column :bank_accounts, :belvo_account_id, :string, null: true
    add_column :bank_accounts, :last_synced_at, :datetime, null: true
    add_column :bank_accounts, :sync_status, :string, null: true

    add_index :bank_accounts, :belvo_account_id, unique: true, where: "belvo_account_id IS NOT NULL"
  end
end
