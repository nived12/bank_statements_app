class AddDiscardedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :discarded_at, :datetime
    add_index :users, :discarded_at

    # Replace the full email uniqueness with a partial index that only enforces
    # uniqueness for active (non-discarded) users. This lets a discarded user
    # keep their original email and still allows a fresh signup with that email.
    remove_index :users, :email
    add_index :users, :email,
      unique: true,
      where: "discarded_at IS NULL",
      name: "index_users_on_email_active"
  end
end
