class FixJtiUniqueIndex < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing unique index on jti
    remove_index :users, :jti if index_exists?(:users, :jti)

    # Populate jti for all existing users to avoid null values
    # Using raw SQL to avoid dependency on User model (which may change in future)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
      # PostgreSQL has gen_random_uuid() function
      execute "UPDATE users SET jti = gen_random_uuid()::text WHERE jti IS NULL"
    else
      # Fallback for other databases (like SQLite in test)
      # Generate UUIDs in Ruby and update
      connection.execute("SELECT id FROM users WHERE jti IS NULL").each do |row|
        uuid = SecureRandom.uuid
        execute "UPDATE users SET jti = '#{uuid}' WHERE id = #{row["id"]}"
      end
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
