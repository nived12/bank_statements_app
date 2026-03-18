class AddCashAccountType < ActiveRecord::Migration[8.0]
  def change
    change_column_null :bank_accounts, :bank_id, true
  end
end
