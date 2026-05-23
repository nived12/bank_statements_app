# frozen_string_literal: true

class CreateUserQuotas < ActiveRecord::Migration[8.0]
  def up
    create_table :user_quota do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer  :ai_usage_count,           default: 0, null: false
      t.datetime :ai_usage_reset_at
      t.integer  :ai_usage_anchor_day
      t.integer  :ai_usage_threshold_shown,  default: 0, null: false
      t.timestamps
    end

    execute <<~SQL
      INSERT INTO user_quota (user_id, ai_usage_count, ai_usage_threshold_shown, created_at, updated_at)
      SELECT id, 0, 0, NOW(), NOW() FROM users
    SQL
  end

  def down
    drop_table :user_quota
  end
end
