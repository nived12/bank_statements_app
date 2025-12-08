class AddJwtColumnsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :jti, :string
    add_column :users, :refresh_token_expires_at, :datetime

    add_index :users, :jti, unique: true unless index_exists?(:users, :jti)
  end
end
