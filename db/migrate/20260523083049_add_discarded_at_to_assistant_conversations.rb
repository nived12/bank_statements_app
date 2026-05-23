class AddDiscardedAtToAssistantConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :assistant_conversations, :discarded_at, :datetime
    add_index :assistant_conversations, :discarded_at
  end
end
