class AddOpeningBalanceDateToBankAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :bank_accounts, :opening_balance_date, :date, null: false, default: -> { 'CURRENT_DATE' }

    # Add an index for better performance on date queries
    add_index :bank_accounts, :opening_balance_date
  end
end
