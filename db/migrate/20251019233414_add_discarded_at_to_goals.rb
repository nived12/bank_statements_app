class AddDiscardedAtToGoals < ActiveRecord::Migration[8.0]
  def change
    add_column :goals, :discarded_at, :datetime
    add_index :goals, :discarded_at
  end
end
