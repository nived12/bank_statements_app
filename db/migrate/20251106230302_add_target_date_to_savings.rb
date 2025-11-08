class AddTargetDateToSavings < ActiveRecord::Migration[8.0]
  def change
    add_column :savings, :target_date, :date
    add_index :savings, :target_date
  end
end
