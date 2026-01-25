class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :preferences, default: {}, null: false

      t.timestamps
    end
  end
end
