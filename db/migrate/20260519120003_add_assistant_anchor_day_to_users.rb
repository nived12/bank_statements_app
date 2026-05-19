# frozen_string_literal: true

class AddAssistantAnchorDayToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :assistant_anchor_day, :integer
  end
end
