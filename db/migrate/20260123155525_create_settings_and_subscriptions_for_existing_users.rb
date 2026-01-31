class CreateSettingsAndSubscriptionsForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      # Create user_settings if doesn't exist
      unless UserSettings.exists?(user_id: user.id)
        UserSettings.create!(user_id: user.id, preferences: {})
      end

      # Create subscription if doesn't exist (existing users get active free plan, not trial)
      unless Subscription.exists?(user_id: user.id)
        Subscription.create!(
          user_id: user.id,
          plan: 'free',
          status: 'active',
          trial_ends_at: nil,
          current_period_end: nil
        )
      end
    end
  end

  def down
    # No rollback needed - records will be destroyed with dependent: :destroy
  end
end
