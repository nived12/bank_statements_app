class BackfillUserSetting < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      next if user.user_setting.present?

      UserSetting.create!(user: user)
    end
  end

  def down
    # No-op: we don't want to delete user_settings on rollback
  end
end
