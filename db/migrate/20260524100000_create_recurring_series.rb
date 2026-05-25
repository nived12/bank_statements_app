# frozen_string_literal: true

class CreateRecurringSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_series do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :name, null: false, limit: 120
      t.string  :description_signature, null: false, limit: 200
      t.string  :merchant_hint, limit: 120
      t.decimal :expected_amount, precision: 12, scale: 2, null: false
      t.decimal :amount_variance_pct, precision: 5, scale: 2, null: false, default: 0
      t.string  :frequency, null: false
      t.integer :custom_interval_days
      t.date    :next_due_date, null: false
      t.date    :last_charged_at
      t.date    :last_notified_on
      t.references :category, foreign_key: true
      t.string  :transaction_type, null: false
      t.string  :status, null: false, default: "active"
      t.string  :source, null: false
      t.integer :confidence_score
      t.integer :occurrences_count, null: false, default: 0
      t.text    :notes
      t.datetime :detected_at
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :recurring_series, [:user_id, :status]
    add_index :recurring_series, [:user_id, :next_due_date]
    add_index :recurring_series, [:user_id, :description_signature], unique: true,
      name: "index_recurring_series_on_user_and_signature"
  end
end
