# frozen_string_literal: true

class AddAssistantQuotaToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :assistant_messages_this_month, :integer, null: false, default: 0
    add_column :users, :assistant_messages_reset_at,   :datetime
  end
end
