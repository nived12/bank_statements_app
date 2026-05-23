# frozen_string_literal: true

class CreateAssistantConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :assistant_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :title, limit: 120
      t.string  :locale, limit: 8, null: false, default: "es-MX"
      t.datetime :last_message_at
      t.integer :message_count, null: false, default: 0
      t.boolean :disclaimer_shown, null: false, default: false
      t.timestamps
    end

    add_index :assistant_conversations, [:user_id, :last_message_at]
  end
end
