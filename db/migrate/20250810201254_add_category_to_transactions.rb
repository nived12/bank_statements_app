class AddCategoryToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions, :category, null: true, foreign_key: true, index: true
    remove_column :transactions, :category, :string
    remove_column :transactions, :sub_category, :string
  end
end
