class FixJtiUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing unique index on jti
    remove_index :users, :jti if index_exists?(:users, :jti)

    # Populate jti for all existing users to avoid null values
    User.where(jti: nil).find_each do |user|
      user.update_column(:jti, SecureRandom.uuid)
    end

    # Add unique index back (now all users have non-null jti values)
    add_index :users, :jti, unique: true
  end

  def down
    # Remove the unique index
    remove_index :users, :jti if index_exists?(:users, :jti)

    # Add it back as it was (for rollback consistency)
    add_index :users, :jti, unique: true
  end
end
