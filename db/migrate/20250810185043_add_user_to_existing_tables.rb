class AddUserToExistingTables < ActiveRecord::Migration[8.0]
  def change
    add_reference :bank_accounts, :user, null: false, foreign_key: true, index: true
    add_reference :statement_files, :user, null: false, foreign_key: true, index: true
    add_reference :transactions, :user, null: false, foreign_key: true, index: true
  end
end
