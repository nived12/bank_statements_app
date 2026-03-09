class CreateSettingsAndSubscriptionsForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      # Create user_settings if doesn't exist
      unless UserSettings.exists?(user_id: user.id)
        UserSettings.create!(user_id: user.id, preferences: {})
      end

      # Subscriptions replaced by Pay gem and local trial_ends_at on users
    end
  end

  def down
    # No rollback needed - records will be destroyed with dependent: :destroy
  end
end
