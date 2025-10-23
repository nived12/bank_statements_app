class CreateDebts < ActiveRecord::Migration[8.0]
  def change
    create_table :debts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.references :goal, null: true, foreign_key: true
      t.references :bank_account, null: true, foreign_key: true
      t.string :name, null: false
      t.decimal :original_amount, precision: 12, scale: 2
      t.decimal :current_balance, precision: 12, scale: 2, null: false
      t.decimal :interest_rate, precision: 5, scale: 2
      t.decimal :minimum_payment, precision: 12, scale: 2
      t.boolean :auto_link_category, default: false, null: false
      t.jsonb :calculation_settings, default: {}, null: false
      t.string :status, default: "active", null: false
      t.text :notes
      t.datetime :discarded_at

      t.timestamps
    end
  end
end
