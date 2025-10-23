class RemoveOldFieldsFromGoals < ActiveRecord::Migration[8.0]
  def change
    remove_column :goals, :category_id, :integer
    remove_column :goals, :bank_account_id, :integer
    remove_column :goals, :auto_link_category, :boolean
    remove_column :goals, :target_amount, :decimal
    remove_column :goals, :current_amount, :decimal
    remove_column :goals, :starting_debt_amount, :decimal
    remove_column :goals, :interest_rate, :decimal
  end
end
