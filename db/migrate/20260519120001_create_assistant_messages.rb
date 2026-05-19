# frozen_string_literal: true

class CreateAssistantMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :assistant_messages do |t|
      t.references :assistant_conversation, null: false, foreign_key: true, index: { name: "idx_asst_msgs_on_conv" }
      t.references :user, null: false, foreign_key: true
      t.string  :role, null: false
      t.text    :content, null: false
      t.string  :intent, limit: 64
      t.boolean :is_deterministic, null: false, default: false
      t.integer :prompt_tokens, default: 0
      t.integer :completion_tokens, default: 0
      t.integer :latency_ms
      t.decimal :cost_usd, precision: 10, scale: 6, default: 0
      t.string  :provider, limit: 16
      t.string  :model, limit: 64
      t.jsonb   :context_snapshot, default: {}
      t.jsonb   :next_best_action, default: {}
      t.timestamps
    end

    add_index :assistant_messages, [:user_id, :created_at]
    add_index :assistant_messages, [:is_deterministic, :created_at]
  end
end
