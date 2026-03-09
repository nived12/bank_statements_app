# frozen_string_literal: true

class BackfillTrialEndsAtAndDropSubscriptions < ActiveRecord::Migration[8.0]
  def up
    # Backfill trial_ends_at for existing users so they keep upload access (local trial)
    trial_days = ENV.fetch("TRIAL_DURATION_DAYS", 30).to_i
    User.where(trial_ends_at: nil).update_all(trial_ends_at: trial_days.days.from_now)

    drop_table :subscriptions
  end

  def down
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :plan, null: false, default: "free"
      t.string :status, null: false, default: "trialing"
      t.datetime :trial_ends_at
      t.datetime :current_period_end
      t.timestamps
    end
    add_index :subscriptions, :plan
    add_index :subscriptions, :status
  end
end
