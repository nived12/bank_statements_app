# frozen_string_literal: true

class AddLastSubjectToAssistantConversations < ActiveRecord::Migration[8.0]
  def change
    add_column :assistant_conversations, :last_subject, :jsonb, default: {}, null: false
  end
end
