class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.references :user, null: true, foreign_key: true, index: true  # null => global
      t.string :name, null: false
      t.references :parent, null: true, foreign_key: { to_table: :categories }, index: true

      t.timestamps
    end

    add_index :categories, %i[user_id parent_id name], unique: true, name: "idx_categories_user_parent_name"
  end
end
