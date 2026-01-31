class AddTrialEndsAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trial_ends_at, :datetime
  end
end
