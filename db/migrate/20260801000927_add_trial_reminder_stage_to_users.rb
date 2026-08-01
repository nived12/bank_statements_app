class AddTrialReminderStageToUsers < ActiveRecord::Migration[8.0]
  def change
    # Milestone (7/3/1) of the last trial-ending email sent; nil = none sent.
    # Monotonically decreasing — see Trial::ReminderJob.
    add_column :users, :trial_reminder_stage, :integer

    # Trial::ReminderJob scans this daily. Partial index because the job only
    # ever looks at kept, confirmed users.
    add_index :users, :trial_ends_at,
      where: "discarded_at IS NULL AND confirmed_at IS NOT NULL",
      name: "index_users_on_trial_ends_at_active"
  end
end
