class AddPaymentModeToDebts < ActiveRecord::Migration[8.0]
  def change
    add_column :debts, :payment_mode, :string
    add_column :debts, :target_payment_amount, :decimal, precision: 12, scale: 2
    add_column :debts, :target_payoff_date, :date
    add_index :debts, :target_payoff_date
  end
end
