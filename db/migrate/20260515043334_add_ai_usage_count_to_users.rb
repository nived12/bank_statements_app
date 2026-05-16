class AddAiUsageCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :ai_usage_count, :integer, null: false, default: 0
  end
end
