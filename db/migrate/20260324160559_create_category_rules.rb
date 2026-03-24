class CreateCategoryRules < ActiveRecord::Migration[8.0]
  def change
    create_table :category_rules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :match_type, null: false, default: "contains"
      t.string :pattern, null: false
      t.integer :priority, null: false, default: 0
      t.boolean :auto_generated, null: false, default: true
      t.integer :hits_count, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :category_rules, [:user_id, :pattern, :match_type], unique: true,
      name: "idx_category_rules_user_pattern_match"
    add_index :category_rules, [:user_id, :active], name: "idx_category_rules_user_active"
  end
end
