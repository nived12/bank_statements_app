# frozen_string_literal: true

class AddToolsCalledToAssistantMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :assistant_messages, :tools_called, :jsonb, default: []
  end
end
