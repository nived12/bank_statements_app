class CreateBankAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :bank_accounts do |t|
      t.string :bank_name
      t.string :account_number
      t.string :currency
      t.decimal :opening_balance, precision: 12, scale: 2

      t.timestamps
    end
  end
end
