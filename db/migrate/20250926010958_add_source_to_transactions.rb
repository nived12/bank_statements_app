class AddSourceToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :source, :integer, default: 0, null: false
    add_index :transactions, :source
  end
end
