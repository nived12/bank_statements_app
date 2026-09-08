class CreateAnnouncementDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :announcement_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :campaign, null: false
      # Nil means the row claimed the slot but delivery never got enqueued.
      # Querying for it gives you the retry list.
      t.datetime :sent_at

      t.timestamps
    end

    # The idempotency guarantee. Application-side checks race between workers;
    # this does not.
    add_index :announcement_deliveries, [ :user_id, :campaign ], unique: true
  end
end
