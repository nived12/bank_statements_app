class CreateBelvoLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :belvo_links do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :bank, null: true, foreign_key: true
      t.string :belvo_link_id, null: false
      t.string :belvo_institution, null: false
      t.string :status, null: false, default: "active"
      t.string :access_mode, null: false, default: "recurrent"
      t.datetime :last_synced_at
      t.string :sync_status, default: "pending"
      t.text :sync_error_message
      t.timestamps
    end

    add_index :belvo_links, :belvo_link_id, unique: true
    add_index :belvo_links, [:user_id, :belvo_institution], unique: true
    add_index :belvo_links, :status
    add_index :belvo_links, :sync_status
  end
end
