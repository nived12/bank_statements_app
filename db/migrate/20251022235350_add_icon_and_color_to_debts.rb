class AddIconAndColorToDebts < ActiveRecord::Migration[8.0]
  def change
    add_column :debts, :icon, :string
    add_column :debts, :color, :string, default: "#EF4444"
  end
end
