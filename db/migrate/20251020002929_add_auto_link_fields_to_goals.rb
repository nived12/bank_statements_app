class AddAutoLinkFieldsToGoals < ActiveRecord::Migration[8.0]
  def change
    add_reference :goals, :bank_account, null: true, foreign_key: true
    add_column :goals, :track_reverse_transactions, :boolean, default: false, null: false
  end
end
