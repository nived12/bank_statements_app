class CreateSavings < ActiveRecord::Migration[8.0]
  def change
    create_table :savings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.references :bank_account, null: true, foreign_key: true
      t.string :name, null: false
      t.decimal :target_amount, precision: 12, scale: 2, null: false
      t.decimal :current_amount, precision: 12, scale: 2, default: 0, null: false
      t.boolean :auto_link_category, default: false, null: false
      t.jsonb :calculation_settings, default: {}, null: false
      t.string :icon
      t.string :color, default: "#3B82F6"
      t.string :status, default: "active", null: false
      t.text :notes
      t.datetime :discarded_at

      t.timestamps
    end
  end
end
