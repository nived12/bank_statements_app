class RemoveGoogleNameFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :google_name, :string
  end
end
