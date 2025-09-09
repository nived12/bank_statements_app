class AddOauthFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :avatar_url, :string
    add_column :users, :google_name, :string

    # Add indexes for OAuth lookups
    add_index :users, [ :provider, :uid ], unique: true, name: 'index_users_on_provider_and_uid'
  end
end
