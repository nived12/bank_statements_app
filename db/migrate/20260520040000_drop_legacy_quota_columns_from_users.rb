# frozen_string_literal: true

class DropLegacyQuotaColumnsFromUsers < ActiveRecord::Migration[8.0]
  def up
    remove_column :users, :ai_usage_count,                  :integer
    remove_column :users, :assistant_messages_this_month,   :integer
    remove_column :users, :assistant_messages_reset_at,     :datetime
    remove_column :users, :assistant_anchor_day,            :integer
    remove_column :users, :assistant_threshold_shown,       :integer
  end

  def down
    add_column :users, :ai_usage_count,                 :integer, default: 0, null: false
    add_column :users, :assistant_messages_this_month,  :integer, default: 0, null: false
    add_column :users, :assistant_messages_reset_at,    :datetime
    add_column :users, :assistant_anchor_day,           :integer
    add_column :users, :assistant_threshold_shown,      :integer, default: 0, null: false
  end
end
