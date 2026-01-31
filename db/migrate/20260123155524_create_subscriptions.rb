class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.string :plan, null: false, default: 'free'
      t.string :status, null: false, default: 'trialing'
      t.datetime :trial_ends_at
      t.datetime :current_period_end

      t.timestamps
    end

    add_index :subscriptions, :plan
    add_index :subscriptions, :status
  end
end
