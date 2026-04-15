class CreateWaitlists < ActiveRecord::Migration[8.0]
  def change
    create_table :waitlists do |t|
      t.string :email, null: false
      t.string :locale, null: false, default: "es"

      t.timestamps
    end

    add_index :waitlists, :email, unique: true
  end
end
