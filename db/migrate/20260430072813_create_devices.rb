# frozen_string_literal: true

class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :push_token, null: false
      t.string :platform, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :devices, %i[user_id push_token], unique: true
    add_index :devices, :push_token
  end
end
