# frozen_string_literal: true

class AddAssistantThresholdShownToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :assistant_threshold_shown, :integer, default: 0, null: false
  end
end
