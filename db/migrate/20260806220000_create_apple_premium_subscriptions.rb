class CreateApplePremiumSubscriptions < ActiveRecord::Migration[8.0]
  def change
    # Current entitlement state for App Store subscribers, one row per user,
    # upserted by the RevenueCat webhook. A projection, not a log — Apple and
    # RevenueCat both keep the real history.
    create_table :apple_premium_subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      t.datetime :expires_at, null: false
      t.string :billing_interval
      t.integer :billing_amount_cents
      t.string :billing_currency

      # False once the user turns off auto-renew in iOS Settings (RevenueCat
      # CANCELLATION). Access continues to expires_at, so without this the API
      # would report cancel_at_period_end: false to someone who has cancelled.
      t.boolean :auto_renews, null: false, default: true

      # Apple's stable id for the subscription across renewals. Lets a webhook
      # be traced back to a StoreKit transaction when one looks wrong.
      t.string :original_transaction_id

      t.timestamps
    end
  end
end
